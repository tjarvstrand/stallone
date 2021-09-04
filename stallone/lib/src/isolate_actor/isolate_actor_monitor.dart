import 'dart:async';
import 'dart:isolate';

import '../actor_monitor.dart';

class IsolateActorMonitor implements ActorMonitor {
  final Isolate _isolate;
  final ReceivePort _port;
  @override
  late Future<ActorMonitorResult> future;

  IsolateActorMonitor(this._isolate) : _port = ReceivePort() {
    _isolate
      ..addErrorListener(_port.sendPort)
      ..addOnExitListener(_port.sendPort);

    future = _port.map((event) => event is List ? Failed(event.first) : Done()).first;
  }

  @override
  Future<void> cancel() {
    _isolate
      ..removeOnExitListener(_port.sendPort)
      ..removeErrorListener(_port.sendPort);
    _port.sendPort.send(Cancelled());
    return Future.value(null);
  }
}
