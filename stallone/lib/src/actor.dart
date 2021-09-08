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
  State _state;

  @protected
  State get state => _state;

  @protected
  set state(State newState) {
    final oldState = state;
    _state = newState;
    if (oldState != state) _stateSink.add(state);
  }

  @protected
  void self(dynamic message) => _mailbox.addOther(Event(message));

  @internal
  final Logger logger = PrintLogger();

  late MailBox _mailbox;
  @protected
  MailBox createMailBox(Stream control, Stream messages) => DefaultMailBox(control, messages);

  Actor(this._state);

  @internal
  Future<void> run() => _runSafe(() async {
        await Future.doWhile(() async {
          final message = await _mailbox.next;
          logger.finest("actor received message: $message");
          if (message is Request && message.payload is Stop) {
            await handleStop();
            _controlChannel.respond(message.id, Stopped());
            return false;
          } else if (message is Request) {
            await handleAsk(message.payload, (m) => _messageChannel.respond(message.id, m));
          } else if (message is Event) {
            await handleTell(message.payload);
          } else {
            await handleOther(message);
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
        _mailbox = createMailBox(
          _controlChannel.stream,
          _messageChannel.stream,
        );
        // Ensure that we populate the state ValueStream
        _stateSink.add(state);
        await handleInit();
        controlChannel.send(InitComplete());
      });

  @nonVirtual
  void stop() => _mailbox.addControl(Stop());

  @protected
  Future<void> handleTell(Req message) async => state;
  @protected
  Future<void> handleAsk(Req request, void Function(Resp) respond) => Future.value(null);
  @protected
  Future<void> handleInit() => Future.value(null);
  @protected
  Future<void> handleStop() => Future.value(null);
  @protected
  Future<void> handleOther(dynamic message) async {
    logger.warning("Received unsupported message type: ${message.runtimeType}");
  }

  @protected
  void onError(dynamic error, StackTrace? stacktrace) {
    logger.severe("Actor died", error, stacktrace);
  }
}
