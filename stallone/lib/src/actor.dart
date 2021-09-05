import 'dart:async';

import 'package:meta/meta.dart';
import 'package:rxdart/rxdart.dart';
import 'package:stallone/src/mailbox.dart';

import 'actor_monitor.dart';
import 'logger.dart';
import 'messages.dart';
import 'util/request_channel.dart';

abstract class ActorRef<Req, Resp, State> {
  void tell(Req message);
  Future<Resp> ask(Req message);
  Future<void> stop();
  ActorMonitor monitor();
  ValueStream<State> get state;
}

abstract class Actor<Req, Resp, State> {
  late ResponseChannel _messageChannel;
  late ResponseChannel<ControlMessage, ControlResponse> _controlChannel;
  late EventSink _stateSink;
  State __state;
  State get _state => __state;
  set _state(State newState) {
    final oldState = _state;
    __state = newState;
    if (oldState != _state) _stateSink.add(_state);
  }

  @protected
  void self(Req request) => _mailbox.addOther(Event(request));

  @internal
  final Logger logger = PrintLogger();

  late MailBox _mailbox;

  Actor(this.__state);

  @internal
  Future<void> run() => _runSafe(() async {
        await Future.doWhile(() async {
          final message = await _mailbox.next;
          logger.finest("actor received message: $message");
          if (message is Request && message.payload is Stop) {
            await handleStop(_state);
            _controlChannel.respond(message.id, Stopped());
            return false;
          } else if (message is Request) {
            _state = await handleAsk(_state, message.payload, (m) => _messageChannel.respond(message.id, m));
          } else if (message is Event) {
            _state = await handleTell(_state, message.payload);
          } else {
            await handleOther(_state, message);
          }
          logger.finest("actor handled message");
          return true;
        });
        logger.finer("actor done");
        _close();
      });

  Future<void> _runSafe(Future<void> Function() f) async {
    try {
      await f();
      // ignore: avoid_catches_without_on_clauses
    } catch (error, trace) {
      onError(error, trace);
      _close();
      rethrow;
    }
  }

  void _close() {
    _stateSink.close();
    _controlChannel.close();
    _messageChannel.close();
    _mailbox.close();
  }

  @internal
  Future<void> init(
    ResponseChannel messageChannel,
    ResponseChannel<ControlMessage, ControlResponse> controlChannel,
    EventSink sink,
  ) =>
      _runSafe(() async {
        _controlChannel = controlChannel;
        _messageChannel = messageChannel;
        _stateSink = sink;
        _mailbox = DefaultMailBox(
          _controlChannel.stream,
          _messageChannel.stream,
        );
        // Ensure that we populate the state ValueStream
        _stateSink.add(_state);
        _state = await handleInit(_state);
        controlChannel.send(InitComplete());
      });

  @nonVirtual
  void stop() => _mailbox.addControl(Stop());

  @protected
  Future<State> handleTell(State state, Req message) async => state;
  @protected
  Future<State> handleAsk(State state, Req request, void Function(Resp) respond) => Future.value(state);
  @protected
  Future<State> handleInit(State state) => Future.value(state);
  @protected
  Future<void> handleStop(State state) => Future.value(null);
  @protected
  Future<void> handleOther(State state, dynamic message) async =>
      logger.warning("Received unsupported message type: ${message.runtimeType}");

  @protected
  void onError(dynamic error, StackTrace? stacktrace) {
    logger.severe("Actor died", error, stacktrace);
  }
}
