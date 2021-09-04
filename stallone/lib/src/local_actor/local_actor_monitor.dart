import 'dart:async';

import '../actor_monitor.dart';

class LocalActorMonitor extends ActorMonitor {
  final Completer<ActorMonitorResult> _actorCompleter;
  final Completer<ActorMonitorResult> _completer = Completer();
  @override
  late Future<ActorMonitorResult> future;

  LocalActorMonitor(this._actorCompleter) {
    future = Future.any([_actorCompleter.future, _completer.future]);
  }

  @override
  Future<void> cancel() async => _completer.complete(Cancelled());
}
