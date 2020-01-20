import 'package:meta/meta.dart';

@immutable
abstract class WorldBossesEvent {}

class LoadWorldbossesEvent extends WorldBossesEvent {
  final bool showLoading;
  final bool includeProgress;

  LoadWorldbossesEvent(this.showLoading, this.includeProgress);
}