import 'dart:async';
import 'dart:isolate';

import 'package:rxdart/rxdart.dart';
import 'package:rxdart/transformers.dart';

import '../actor.dart';
import 'isolate_actor_monitor.dart';

class SendPortStreamSink<T> implements EventSink<T> {
  final SendPort _port;

  SendPortStreamSink(this._port);

  @override
  void add(T event) => _port.send(event);

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  void close() {}
}

Future<void> isolateMain(
  IsolateActorInit init,
) async {
  final actor = init.actor;
  final messageReceivePort = ReceivePort();
  final controlReceivePort = ReceivePort();
  init.controlMessageResponsePort.send([messageReceivePort.sendPort, controlReceivePort.sendPort]);
  await actor.init(init.statePort.send);
  init.controlMessageResponsePort.send(#initComplete);
  try {
    await actor.run(messageReceivePort, controlReceivePort);
  } finally {
    messageReceivePort.close();
    controlReceivePort.close();
  }
}

class IsolateActorInit<Req, Resp> {
  final Actor<Req, Resp, dynamic> actor;
  final SendPort messageResponsePort;
  final SendPort controlMessageResponsePort;
  final SendPort statePort;

  IsolateActorInit(this.actor, this.messageResponsePort, this.controlMessageResponsePort, this.statePort);
}

class IsolateActorRequest<T, R> extends Request<T, R> {
  final SendPort _sendPort;
  IsolateActorRequest(int id, T payload, this._sendPort) : super(id, payload);
  @override
  void respond(Response<R> response) => _sendPort.send(response);
}

class IsolateActorStopped {}

class IsolateActorStop extends Stop {
  final SendPort _responsePort;

  IsolateActorStop(this._responsePort);

  @override
  void respond() => _responsePort.send(IsolateActorStopped());
}

class IsolateActorRef<Req, Resp, State> extends ActorRef<Req, Resp, State> {
  int nextRequestId = 0;
  final Isolate _isolate;
  final SendPort _messageSendPort;
  final ReceivePort _messageResponsePort;
  final Stream<Response> _messageResponseStream;
  final SendPort _controlMessageSendPort;
  final ReceivePort _controlMessageResponsePort;
  final Stream _controlMessageResponseStream;
  final ReceivePort _statePort;
  @override
  final ValueStream<State> stream;

  IsolateActorRef._(this._isolate, this._messageSendPort, ReceivePort messageResponsePort, this._controlMessageSendPort,
      this._controlMessageResponsePort, this._controlMessageResponseStream, this._statePort, this.stream)
      : _messageResponsePort = messageResponsePort,
        _messageResponseStream = messageResponsePort.asBroadcastStream().whereType<Response>();

  static Future<IsolateActorRef<Req, Resp, State>> start<Req, Resp, State>(
    Actor<Req, Resp, State> actor, [
    bool awaitInit = true,
  ]) async {
    final messageResponsePort = ReceivePort();
    final controlMessageResponsePort = ReceivePort();
    final controlMessageResponseStream = controlMessageResponsePort.asBroadcastStream();

    final stateReceivePort = ReceivePort();
    // ignore: close_sinks
    final stateStream = BehaviorSubject<State>();
    stateReceivePort.whereType<State>().listen(stateStream.add);
    final isolate = await Isolate.spawn(
      isolateMain,
      IsolateActorInit<Req, Resp>(
        actor,
        messageResponsePort.sendPort,
        controlMessageResponsePort.sendPort,
        stateReceivePort.sendPort,
      ),
    );
    final ports = await controlMessageResponseStream.first as List;
    if (awaitInit) {
      await controlMessageResponseStream.firstWhere((message) => message == #initComplete);
    }

    return IsolateActorRef._(
      isolate,
      ports[0] as SendPort,
      messageResponsePort,
      ports[1] as SendPort,
      controlMessageResponsePort,
      controlMessageResponseStream,
      stateReceivePort,
      stateStream,
    );
  }

  @override
  void tell(Req message) => _messageSendPort.send(Event(message));

  @override
  Future<Resp> ask(Req message) async {
    final requestId = nextRequestId++;
    _messageSendPort.send(IsolateActorRequest(requestId, message, _messageResponsePort.sendPort));
    return (await _messageResponseStream.firstWhere((msg) => msg.requestId == requestId)).payload as Resp;
  }

  @override
  IsolateActorMonitor monitor() => IsolateActorMonitor(_isolate);

  @override
  Future<void> stop() async {
    // todo: timeout
    final port = ReceivePort();
    _isolate.addOnExitListener(port.sendPort);
    _controlMessageSendPort.send(IsolateActorStop(_controlMessageResponsePort.sendPort));
    await _controlMessageResponseStream.whereType<IsolateActorStopped>().first;
    _controlMessageResponsePort.close();
    _messageResponsePort.close();
    _statePort.close();
    await port.first;
  }
}
