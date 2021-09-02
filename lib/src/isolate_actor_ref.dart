import 'dart:async';
import 'dart:isolate';

import 'package:meta/meta.dart';
import 'package:rxdart/transformers.dart';

import 'actor.dart';

Future<void> _isolateMain(
  _ActorInit init,
) async {
  final actor = init.actor;
  final sendPort = init.sendPort;
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);
  await actor.init();
  sendPort.send(#initComplete);
  await for (final message in receivePort) {
    if (message is _Message) {
      await actor.tell(message.payload);
    } else if (message is _Request) {
      await actor.ask(message.payload, (m) {
        message._responsePort.send(_Response(m));
      });
    } else if (message == #stop) {
      await actor.stop();
    } else {
      print("Received unsupported message type: ${message.runtimeType}");
    }
  }
}

class _ActorInit<Req, Resp> {
  final Actor<Req, Resp, dynamic> actor;
  final SendPort sendPort;

  _ActorInit(this.actor, this.sendPort);
}

abstract class _MessageBase<T> {
  final T payload;

  _MessageBase(this.payload);
}

class _Message<T> extends _MessageBase<T> {
  _Message(T payload) : super(payload);
}

class _Request<T, R> extends _MessageBase<T> {
  final SendPort _responsePort;
  _Request(T payload, this._responsePort) : super(payload);
}

class _Response<T> extends _MessageBase<T> {
  _Response(T payload) : super(payload);
}

class IsolateActorMonitor implements ActorMonitor {
  final Isolate _isolate;
  final ReceivePort _port;
  @override
  late Future<ActorMonitorResult> future;

  IsolateActorMonitor._(this._isolate) : _port = ReceivePort() {
    _isolate
      ..addErrorListener(_port.sendPort)
      ..addOnExitListener(_port.sendPort);

    future = _port.map((event) => event is List ? Failed(event.first) : Stopped()).first;
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

class IsolateActorRef<Req, Resp> extends ActorRef<Req, Resp> {
  final ReceivePort _responsePort;
  final Stream _responseStream;
  final SendPort _requestPort;
  final Isolate _isolate;

  @internal
  static Future<IsolateActorRef<Req, Resp>> start<Req, Resp>(Actor<Req, Resp, dynamic> actor, bool awaitInit) async {
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
  void tell(Req message) => _requestPort.send(_Message(message));

  @override
  Future<Resp> ask(Req message) async {
    _requestPort.send(_Request(message, _responsePort.sendPort));
    return (await _responseStream.whereType<_Response>().first).payload as Resp;
  }

  @override
  IsolateActorMonitor monitor() => IsolateActorMonitor._(_isolate);

  @override
  Future<void> stop() async {
    final port = ReceivePort();
    _isolate.addOnExitListener(port.sendPort);
    _requestPort.send(#stop);
    await port.first;
    _responsePort.close();
  }
}
