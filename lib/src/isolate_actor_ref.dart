part of stallone;

Future<void> _isolateMain(
  _ActorInit init,
) async {
  final actor = init.actor;
  final sendPort = init.sendPort;
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);
  await actor._initialize();
  sendPort.send(#initComplete);
  late StreamSubscription sub;
  sub = receivePort.listen((message) async {
    if (message is Message) {
      await actor._handleTell(message.payload);
    } else if (message is Request) {
      await actor._handleAsk(message.payload, (m) {
        message._responsePort.send(Response(m));
      });
    } else if (message == #stop) {
      await sub.cancel();
      await actor._stop();
      // No need to send a response here since the ActorRef will wait for the Isolate to terminate.
    } else {
      print("Received unsupported message type: ${message.runtimeType}");
    }
  });
}

class _ActorInit<Req, Resp> {
  final Actor<Req, Resp, dynamic> actor;
  final SendPort sendPort;

  _ActorInit(this.actor, this.sendPort);
}

abstract class _Message<T> {
  final T payload;

  _Message(this.payload);
}

class Message<T> extends _Message<T> {
  Message(T payload) : super(payload);
}

class Request<T, R> extends _Message<T> {
  final SendPort _responsePort;
  Request(T payload, this._responsePort) : super(payload);
}

class Response<T> extends _Message<T> {
  Response(T payload) : super(payload);
}

class IsolateActorRef<Req, Resp> extends ActorRef<Req, Resp> {
  final ReceivePort _responsePort;
  final Stream _responseStream;
  final SendPort _requestPort;
  final Isolate _isolate;

  static Future<IsolateActorRef<Req, Resp>> _start<Req, Resp>(Actor<Req, Resp, dynamic> actor, bool awaitInit) async {
    final responsePort = ReceivePort();
    final stream = responsePort.asBroadcastStream();
    final isolate = await Isolate.spawn(
      _isolateMain,
      _ActorInit<Req, Resp>(actor, responsePort.sendPort),
    );
    final requestPort = await stream.first as SendPort;
    if (awaitInit) {
      await stream.firstWhere((message) => message == #initComplete);
    }

    return IsolateActorRef<Req, Resp>._(
      isolate,
      responsePort,
      stream,
      requestPort,
    );
  }

  IsolateActorRef._(
    this._isolate,
    this._responsePort,
    this._responseStream,
    this._requestPort,
  );

  @override
  void tell(Req message) => _requestPort.send(Message(message));

  @override
  FutureOr<Resp> ask(Req message) async {
    _requestPort.send(Request(message, _responsePort.sendPort));
    return (await _responseStream.whereType<Response>().first).payload as Resp;
  }

  @override
  FutureOr<void> stop() async {
    _isolate.addOnExitListener(_responsePort.sendPort, response: "stopped");
    _requestPort.send(#stop);
    await _responseStream.firstWhere((message) => message == "stopped");
    _responsePort.close();
  }
}
