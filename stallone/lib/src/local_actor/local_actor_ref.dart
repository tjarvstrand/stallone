import 'dart:async';

import 'package:pedantic/pedantic.dart';
import 'package:rxdart/rxdart.dart';
import 'package:stallone/stallone.dart';

import '../actor.dart';
import '../actor_monitor.dart';

class LocalActorRequest<T, R> extends Request<T, R> {
  final StreamSink _sink;
  LocalActorRequest(int id, T payload, this._sink) : super(id, payload);
  @override
  void respond(Response<R> response) => _sink.add(response);
}

class LocalActorStop extends Stop {
  final Completer<LocalActorStopped> completer = Completer();

  @override
  void respond() => completer.complete(LocalActorStopped());
}

class LocalActorStopped {}

class LocalActorRef<Req, Resp, State> extends ActorRef<Req, Resp, State> {
  int _nextRequestId = 0;
  final StreamController<Message<Req>> _messageController;
  final StreamController<Response<Resp>> _messageResponseController = StreamController.broadcast();
  final StreamController _controlMessageController;
  final Completer<ActorMonitorResult> _completer;
  final Actor<Req, Resp, dynamic> _actor;
  final BehaviorSubject<State> _stateStreamController;

  LocalActorRef(
    this._actor,
    this._messageController,
    this._controlMessageController,
    this._stateStreamController,
    this._completer,
  );

  @override
  ValueStream<State> get stream => _stateStreamController.stream;

  static Future<LocalActorRef<Req, Resp, State>> start<Req, Resp, State>(
    Actor<Req, Resp, State> actor, [
    bool awaitInit = true,
  ]) async {
    // ignore: close_sinks
    final stateStreamController = BehaviorSubject<State>();
    final initF = actor.init(stateStreamController.add);
    if (awaitInit) await initF;
    final messageController = StreamController<Message<Req>>.broadcast();
    final controlMessageController = StreamController.broadcast();
    final completer = Completer<ActorMonitorResult>();
    unawaited(actor
        .run(messageController.stream, controlMessageController.stream)
        .then((_) => completer.complete(Done()))
        .onError((error, __) => completer.complete(Failed(error)))
        .whenComplete(() async {
      await messageController.close();
      await controlMessageController.close();
    }));
    final ref = LocalActorRef(actor, messageController, controlMessageController, stateStreamController, completer);
    unawaited(ref._run());
    return ref;
  }

  Future<void> _run() =>
      _actor.run(_messageController.stream, _controlMessageController.stream).onError((_, __) => null);

  @override
  Future<Resp> ask(Req message) async {
    final requestId = _nextRequestId++;
    _messageController.add(LocalActorRequest<Req, Resp>(requestId, message, _messageResponseController));
    return (await _messageResponseController.stream.firstWhere((response) => response.requestId == requestId)).payload;
  }

  @override
  Future<void> tell(Req message) async => _messageController.add(Event(message));

  @override
  Future<void> stop() async {
    final message = LocalActorStop();
    _controlMessageController.add(message);
    await message.completer.future;
    await _completer.future;
    await Future.wait([
      _messageController.close(),
      _messageResponseController.close(),
      _controlMessageController.close(),
    ]);
  }

  @override
  LocalActorMonitor monitor() => LocalActorMonitor(_completer);
}
