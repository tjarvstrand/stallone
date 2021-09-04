import 'dart:async';

import 'package:meta/meta.dart';

abstract class ActorMonitor {
  Future<ActorMonitorResult> get future;
  Future<void> cancel();
}

@sealed
abstract class ActorMonitorResult {}

class Cancelled extends ActorMonitorResult {}

class Done extends ActorMonitorResult {}

class Failed extends ActorMonitorResult {
  final dynamic reason;

  Failed(this.reason);
}
