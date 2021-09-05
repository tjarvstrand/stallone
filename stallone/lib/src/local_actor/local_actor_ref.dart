import 'dart:async';

import 'package:pedantic/pedantic.dart';
import 'package:rxdart/rxdart.dart';
import 'package:stream_channel/stream_channel.dart';

import '../actor.dart';
import '../actor_monitor.dart';
import '../messages.dart';
import '../util/request_channel.dart';
import 'local_actor_monitor.dart';

class LocalActorRef<Req, Resp, State> extends ActorRef<Req, Resp, State> {
  final Completer<ActorMonitorResult> _completer;
  final RequestChannel<Req, Resp> _messageChannel;
  final RequestChannel<ControlMessage, ControlResponse> _controlChannel;
  @override
  final ValueStream<State> state;

  LocalActorRef._(
    this._completer,
    this._messageChannel,
    this._controlChannel,
    this.state,
  );

  static Future<LocalActorRef<Req, Resp, State>> start<Req, Resp, State>(
    Actor<Req, Resp, State> actor, [
    bool awaitInit = true,
  ]) async {
    final messageController = StreamChannelController();
    final messageChannel = RequestChannel<Req, Resp>(messageController.local);
    final controlController = StreamChannelController();
    final controlChannel = RequestChannel<ControlMessage, ControlResponse>(controlController.local);
    final stateStream = BehaviorSubject<State>();
    final initF = actor.init(
      ResponseChannel(messageController.foreign),
      ResponseChannel(controlController.foreign),
      stateStream,
    );
    if (awaitInit) await initF;
    final completer = Completer<ActorMonitorResult>();
    final ref = LocalActorRef._(completer, messageChannel, controlChannel, stateStream);
    unawaited(actor.run().then((_) {
      completer.complete(Done());
    }).onError((error, __) {
      completer.complete(Failed(error));
    }));
    return ref;
  }

  @override
  void tell(Req message) => _messageChannel.notify(message);

  @override
  Future<Resp> ask(Req message) async => _messageChannel.request(message);

  @override
  Future<void> stop() async {
    await _messageChannel.close();
    await _controlChannel.request(Stop());
    await _controlChannel.close();
    await _completer.future;
  }

  @override
  LocalActorMonitor monitor() => LocalActorMonitor(_completer);
}
