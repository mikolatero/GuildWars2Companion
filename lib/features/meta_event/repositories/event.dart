import 'package:guildwars2_companion/features/event/models/event_segment.dart';
import 'package:guildwars2_companion/features/meta_event/models/meta_event.dart';
import 'package:guildwars2_companion/features/meta_event/services/event.dart';

class MetaEventRepository {
  final EventService eventService;

  MetaEventRepository({
    this.eventService,
  });

  Future<List<MetaEventSequence>> getMetaEvents() async {
    List<MetaEventSequence> events = await eventService.getMetaEvents();

    events.forEach((event) {
      event.segments.forEach((segment) {
        segment.time = null;
        segment.times = [];
      });

      processMetaEventSequence(event);
    });

    return events;
  }

  void processMetaEventSequence(MetaEventSequence sequence) {
    sequence.segments.forEach((segment) {
      segment.time = null;
      segment.times = [];
    });

    DateTime now = DateTime.now().toUtc();
    DateTime offset = DateTime.utc(now.year, now.month, now.day).subtract(sequence.offset);

    while(_getDayValue(offset) <= _getDayValue(now)) {
      sequence.segments.forEach((segment) {
        if (_getDayValue(offset) > _getDayValue(now)) {
          return;
        }

        segment.times.add(offset);
        offset = offset.add(segment.duration);
      });
    }

    sequence.segments.forEach((segment) {
      if (segment.times.isEmpty) {
        return;
      }

      List<MetaEventSegment> duplicates = 
        sequence.segments
          .where((s) => 
            s.id == segment.id
            && s != segment
            && s.duration.inMinutes == segment.duration.inMinutes
          ).toList();

      if (duplicates.isNotEmpty) {
        duplicates.forEach((d) {
          segment.times.addAll(d.times);
          d.times = [];
        });

        segment.times.sort((a, b) => a.compareTo(b));
      }

      segment.time = segment.times
        .firstWhere((t) => t.add(segment.duration).isAfter(now), orElse: () => segment.times[0].add(Duration(days: 1)));
    });

    sequence.segments.removeWhere((s) => s.times.isEmpty || s.time == null);

    sequence.segments.sort((a, b) => a.time.compareTo(b.time));

    sequence.segments.forEach((s) {
      s.times.removeWhere((t) => t.day != now.day);
      s.time = s.time.toLocal();
      s.times = s.times.map((s) => s.toLocal()).toList();
    });
  }

  int _getDayValue(DateTime date) {
    return DateTime.utc(date.year, date.month, date.day).millisecondsSinceEpoch ~/ 86400000;
  }
}