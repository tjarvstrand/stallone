import 'dart:async';
import 'dart:isolate';

import 'package:rxdart/rxdart.dart';
import 'package:rxdart/transformers.dart';
import 'package:stream_channel/isolate_channel.dart';

import '../actor.dart';
import '../util/request_channel.dart';
import 'isolate_actor_monitor.dart';

Future<void> isolateMain(
  IsolateActorSpec spec,
) async {
  final actor = spec.actor;
  final messageResponsePort = ResponseChannel(IsolateChannel.connectSend(spec.messagePort));
  final controlPort = IsolateChannel.connectSend(spec.controlPort);
  final controlResponsePort = ResponseChannel<ControlMessage, ControlResponse>(controlPort);
  final statePort = IsolateChannel.connectSend(spec.statePort);
  await actor.init(messageResponsePort, controlResponsePort, statePort.sink);

  await actor.run();
}

class IsolateActorSpec<Req, Resp> {
  final Actor<Req, Resp, dynamic> actor;
  final SendPort messagePort;
  final SendPort controlPort;
  final SendPort statePort;

  IsolateActorSpec(this.actor, this.messagePort, this.controlPort, this.statePort);
}

class IsolateActorRef<Req, Resp, State> extends ActorRef<Req, Resp, State> {
  final Isolate _isolate;
  final RequestChannel<Req, Resp> _messageChannel;
  final RequestChannel<ControlMessage, ControlResponse> _controlChannel;
  @override
  final ValueStream<State> state;

  IsolateActorRef._(
    this._isolate,
    this._messageChannel,
    this._controlChannel,
    this.state,
  );

  static Future<IsolateActorRef<Req, Resp, State>> start<Req, Resp, State>(
    Actor<Req, Resp, State> actor, [
    bool awaitInit = true,
  ]) async {
    final messagePort = ReceivePort();
    final messageChannel = RequestChannel<Req, Resp>(IsolateChannel.connectReceive(messagePort));
    final controlPort = ReceivePort();
    final controlChannel = IsolateChannel.connectReceive(controlPort);
    final controlRequestChannel = RequestChannel<ControlMessage, ControlResponse>(controlChannel);
    final statePort = ReceivePort();
    // ignore: close_sinks
    final stateStream = BehaviorSubject<State>();
    statePort.whereType<State>().listen(stateStream.add);
    final exitPort = ReceivePort()
      ..listen((a) {
        messageChannel.close();
        controlRequestChannel.close();
        statePort.close();
        stateStream.close();
      });

    final isolate = await Isolate.spawn(
      isolateMain,
      IsolateActorSpec<Req, Resp>(
        actor,
        messagePort.sendPort,
        controlPort.sendPort,
        statePort.sendPort,
      ),
    )
      ..addErrorListener(exitPort.sendPort)
      ..addOnExitListener(exitPort.sendPort);
    controlRequestChannel.stream;
    if (awaitInit) {
      await controlRequestChannel.stream.firstWhere((message) => message is InitComplete);
    }

    return IsolateActorRef._(
      isolate,
      messageChannel,
      controlRequestChannel,
      stateStream,
    );
  }

  @override
  void tell(Req message) => _messageChannel.notify(message);

  @override
  Future<Resp> ask(Req message) async => _messageChannel.request(message);

  @override
  IsolateActorMonitor monitor() => IsolateActorMonitor(_isolate);

  @override
  Future<void> stop() async {
    final port = ReceivePort();
    _isolate.addOnExitListener(port.sendPort);
    await _controlChannel.request(Stop());
    await port.first;
  }
}
