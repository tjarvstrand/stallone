import 'dart:async';

import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';

import 'actor_monitor.dart';
import 'logger.dart';

abstract class Message<T> {
  final T payload;

  Message(this.payload);
}

class Event<T> extends Message<T> {
  Event(T payload) : super(payload);
}

abstract class Request<T, R> extends Message<T> {
  final int id;
  Request(this.id, T payload) : super(payload);
  void respond(Response<R> response);
}

class Response<T> extends Message<T> {
  int requestId;
  Response(this.requestId, T payload) : super(payload);
}

// ignore: one_member_abstracts, can't send closures over SendPorts
abstract class Stop {
  void respond();
}

abstract class ActorRef<Req, Resp, State> {
  void tell(Req message);
  Future<Resp> ask(Req message);
  Future<void> stop();
  ActorMonitor monitor();
  ValueStream<State> get stream;
}

abstract class Actor<Req, Resp, State> {
  late void Function(State) _publishState;
  State __state;
  State get _state => __state;
  set _state(State newState) {
    final oldState = _state;
    __state = newState;
    if (oldState != _state) _publishState(_state);
  }

  @internal
  final Logger logger = DefaultLogger();

  Actor(this.__state);

  @internal
  Future<void> run(Stream messageStream, Stream controlStream) async {
    await for (final message in Rx.merge([messageStream, controlStream])) {
      try {
        if (message is Stop) {
          await stop(message);
          break;
        } else if (message is Event) {
          _state = await handleTell(_state, message.payload);
        } else if (message is Request) {
          _state = await handleAsk(_state, message.payload, (m) => message.respond(Response<Resp>(message.id, m)));
        } else {
          await handleInfo(_state, message);
        }
        // ignore: avoid_catches_without_on_clauses
      } catch (error, trace) {
        onError(error, trace);
        rethrow;
      }
    }
  }

  @internal
  Future<void> init(void Function(State) publishState) async {
    _publishState = publishState;
    // Ensure that we populate the ValueStream by force publishing state after initialization even if it's the same as
    // the initial state.
    __state = await handleInit(_state);
    _publishState(_state);
  }

  @internal
  Future<void> stop(Stop message) async {
    await handleStop(_state);
    message.respond();
  }

  @protected
  Future<State> handleTell(State state, Req message) async => state;
  @protected
  Future<State> handleAsk(State state, Req request, void Function(Resp) respond) => Future.value(state);
  @protected
  Future<State> handleInit(State state) => Future.value(state);
  @protected
  Future<void> handleStop(State state) => Future.value(null);
  @protected
  Future<void> handleInfo(State state, dynamic message) async =>
      logger.warning("Received unsupported message type: ${message.runtimeType}");

  @protected
  void onError(dynamic error, StackTrace? stacktrace) {
    logger.severe("Actor died", error, stacktrace);
  }
}
