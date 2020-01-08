import 'dart:convert';

import 'package:guildwars2_companion/models/achievement/achievement.dart';
import 'package:guildwars2_companion/models/achievement/achievement_category.dart';
import 'package:guildwars2_companion/models/achievement/achievement_group.dart';
import 'package:guildwars2_companion/models/achievement/achievement_progress.dart';
import 'package:guildwars2_companion/models/achievement/daily.dart';
import 'package:guildwars2_companion/utils/token.dart';
import 'package:guildwars2_companion/utils/urls.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class AchievementRepository {
  List<Achievement> _cachedAchievements = [];

  Future<Database> _getDatabase() async {
    return await openDatabase(
      join(await getDatabasesPath(), 'achievements.db'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE achievements(
            id INTEGER PRIMARY KEY,
            icon TEXT,
            name TEXT,
            description TEXT,
            requirement TEXT,
            lockedText TEXT,
            prerequisites TEXT,
            pointCap INTEGER,
            expiration_date DATE
          )
        ''');
        await db.execute('''
          CREATE TABLE bits(
            type TEXT,
            text TEXT,
            id INTEGER,
            achievement_id INTEGER,
            expiration_date DATE
          )
        ''');
        await db.execute('''
          CREATE TABLE tiers(
            count INTEGER,
            points INTEGER,
            achievement_id INTEGER,
            expiration_date DATE
          )
        ''');
        await db.execute('''
          CREATE TABLE rewards(
            type TEXT,
            id INTEGER,
            count INTEGER,
            region TEXT,
            achievement_id INTEGER,
            expiration_date DATE
          )
        ''');
        return;
      },
      version: 1,
    );
  }

  Future<void> loadCachedData() async {
    Database database = await _getDatabase();

    DateTime now = DateTime.now().toUtc();

    await database.delete(
      'achievements',
      where: "expiration_date <= ?",
      whereArgs: [DateFormat('yyyyMMdd').format(now)],
    );

    await database.delete(
      'bits',
      where: "expiration_date <= ?",
      whereArgs: [DateFormat('yyyyMMdd').format(now)],
    );

    await database.delete(
      'tiers',
      where: "expiration_date <= ?",
      whereArgs: [DateFormat('yyyyMMdd').format(now)],
    );

    await database.delete(
      'rewards',
      where: "expiration_date <= ?",
      whereArgs: [DateFormat('yyyyMMdd').format(now)],
    );

    final List<Map<String, dynamic>> achievements = await database.query('achievements');
    for(var a in achievements) {
      Achievement achievement = Achievement.fromDb(a);

      final List<Map<String, dynamic>> bits = await database.query(
        'bits',
        where: 'achievement_id = ?',
        whereArgs: [achievement.id]
      );
      if (bits.isNotEmpty) {
        achievement.bits = List.generate(bits.length, (i) => AchievementBits.fromDb(bits[i]));
      }

      final List<Map<String, dynamic>> tiers = await database.query(
        'tiers',
        where: 'achievement_id = ?',
        whereArgs: [achievement.id]
      );
      if (tiers.isNotEmpty) {
        achievement.tiers = List.generate(tiers.length, (i) => AchievementTiers.fromDb(tiers[i]));
      }

      final List<Map<String, dynamic>> rewards = await database.query(
        'rewards',
        where: 'achievement_id = ?',
        whereArgs: [achievement.id]
      );
      if (rewards.isNotEmpty) {
        achievement.rewards = List.generate(rewards.length, (i) => AchievementRewards.fromDb(rewards[i]));
      }

      _cachedAchievements.add(achievement);
    }
    return;
  }

  int getCachedAchievementsCount() {
    return _cachedAchievements.length;
  }

  Future<List<Achievement>> getAchievements(List<int> achievementIds) async {
    List<Achievement> achievements = [];
    List<int> newAchievementIds = [];

    achievementIds.forEach((achievementId) {
      Achievement item = _cachedAchievements.firstWhere((i) => i.id == achievementId, orElse: () => null);

      if (item != null) {
        achievements.add(item);
      } else {
        newAchievementIds.add(achievementId);
      }
    });

    if (newAchievementIds.isNotEmpty) {
      achievements.addAll(await _getNewAchievements(newAchievementIds));
    }

    return achievements;
  }

  Future<List<Achievement>> _getNewAchievements(List<int> achievementIds) async {
    List<String> achievementIdsList = Urls.divideIdLists(achievementIds);
    List<Achievement> achievements = [];
    for (var achievementIdsString in achievementIdsList) {
      final response = await http.get(
        Urls.achievementsUrl + achievementIdsString,
        headers: {
          'Authorization': 'Bearer ${await TokenUtil.getToken()}',
        }
      );

      if (response.statusCode == 200 || response.statusCode == 206) {
        List responseAchievements = json.decode(response.body);
        achievements.addAll(responseAchievements.map((a) => Achievement.fromJson(a)).toList());
      }
    }

    await _cacheAchievements(achievements);

    return achievements;
  }

  Future<void> _cacheAchievements(List<Achievement> achievements) async {
    Database database = await _getDatabase();

    List<Achievement> nonCachedItems = achievements.where((i) => !_cachedAchievements.any((ca) => ca.id == i.id)).toList();
    _cachedAchievements.addAll(nonCachedItems);

    String expirationDate = DateFormat('yyyyMMdd')
      .format(
        DateTime
        .now()
        .add(Duration(days: 31))
        .toUtc()
      );

    Batch batch = database.batch();
    nonCachedItems.forEach((achievement) {
      batch.insert('achievements', achievement.toDb(expirationDate), conflictAlgorithm: ConflictAlgorithm.ignore);

      if (achievement.bits != null && achievement.bits.isNotEmpty) {
        achievement.bits.forEach((bit) =>
          batch.insert('bits', bit.toDb(expirationDate, achievement.id), conflictAlgorithm: ConflictAlgorithm.ignore));
      }

      if (achievement.tiers != null && achievement.tiers.isNotEmpty) {
        achievement.tiers.forEach((tier) =>
          batch.insert('tiers', tier.toDb(expirationDate, achievement.id), conflictAlgorithm: ConflictAlgorithm.ignore));
      }

      if (achievement.rewards != null && achievement.rewards.isNotEmpty) {
        achievement.rewards.forEach((reward) =>
          batch.insert('rewards', reward.toDb(expirationDate, achievement.id), conflictAlgorithm: ConflictAlgorithm.ignore));
      }
    });
    await batch.commit(noResult: true);

    return;
  }

  Future<List<AchievementProgress>> getAchievementProgress() async {
    final response = await http.get(
      Urls.inventoryUrl,
      headers: {
        'Authorization': 'Bearer ${await TokenUtil.getToken()}',
      }
    );

    if (response.statusCode == 200) {
      List progress = json.decode(response.body);
      return progress.where((a) => a != null).map((a) => AchievementProgress.fromJson(a)).toList();
    } else {
      return [];
    }
  }

  Future<List<AchievementCategory>> getAchievementCategories() async {
    final response = await http.get(
      Urls.achievementCategoriesUrl,
      headers: {
        'Authorization': 'Bearer ${await TokenUtil.getToken()}',
      }
    );

    if (response.statusCode == 200) {
      List categories = json.decode(response.body);
      return categories.where((a) => a != null).map((a) => AchievementCategory.fromJson(a)).toList();
    } else {
      return [];
    }
  }

  Future<List<AchievementGroup>> getAchievementGroups() async {
    final response = await http.get(
      Urls.achievementGroupsUrl,
      headers: {
        'Authorization': 'Bearer ${await TokenUtil.getToken()}',
      }
    );

    if (response.statusCode == 200) {
      List groups = json.decode(response.body);
      return groups.where((a) => a != null).map((a) => AchievementGroup.fromJson(a)).toList();
    } else {
      return [];
    }
  }

  Future<DailyGroup> getDailies() async {
    final response = await http.get(
      Urls.dailiesUrl,
      headers: {
        'Authorization': 'Bearer ${await TokenUtil.getToken()}',
      }
    );

    if (response.statusCode == 200) {
      return DailyGroup.fromJson(json.decode(response.body));
    } else {
      return DailyGroup();
    }
  }
}