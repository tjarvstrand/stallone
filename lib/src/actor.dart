import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

abstract class ActorRef<Req, Resp> {
  void tell(Req message);
  Future<Resp> ask(Req message);
  Future<void> stop();
  ActorMonitor monitor();
}

abstract class ActorMonitor {
  Future<ActorMonitorResult> get future;
  Future<void> cancel();
}

abstract class Actor<Req, Resp, State> {
  State _state;
  Actor(this._state);

  @internal
  Future<void> tell(Req message) async => _state = await handleTell(_state, message);
  Future<State> handleTell(State state, Req message) async => state;

  @internal
  Future<void> ask(Req request, void Function(Resp) respond) async =>
      _state = await handleAsk(_state, request, respond);
  Future<State> handleAsk(State state, Req request, void Function(Resp) respond) => Future.value(state);

  @internal
  Future<void> init() async => _state = await handleInit(_state);
  Future<State> handleInit(State state) => Future.value(state);

  @internal
  Future<void> stop() => handleStop(_state);
  Future<void> handleStop(State state) => Future.value(null);
}

@sealed
abstract class ActorMonitorResult extends Equatable {}

class Cancelled extends ActorMonitorResult {
  @override
  List<Object?> get props => [];
}

class Stopped extends ActorMonitorResult {
  @override
  List<Object?> get props => [];
}

class Failed extends ActorMonitorResult {
  final dynamic reason;

  @override
  List<Object?> get props => [reason];

  Failed(this.reason);
}
