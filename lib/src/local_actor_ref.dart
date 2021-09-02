import 'dart:async';

import 'package:meta/meta.dart';

import 'actor.dart';

class LocalActorMonitor extends ActorMonitor {
  final Future<ActorMonitorResult> _future;
  final Completer<ActorMonitorResult> _completer = Completer();
  @override
  late Future<ActorMonitorResult> future;

  LocalActorMonitor._(this._future) {
    future = Future.any([_future, _completer.future]);
  }

  @override
  Future<void> cancel() async => _completer.complete(Cancelled());
}

abstract class _MessageBase<T> {
  final T payload;

  _MessageBase(this.payload);
}

class _Message<T> extends _MessageBase<T> {
  _Message(T payload) : super(payload);
}

class _Request<T, R> extends _MessageBase<T> {
  final void Function(R) respond;
  _Request(T payload, this.respond) : super(payload);
}

class LocalActorRef<Req, Resp> extends ActorRef<Req, Resp> {
  final _controller = StreamController<_MessageBase<Req>>();
  late StreamSubscription _subscription;
  final _completer = Completer<ActorMonitorResult>();
  final Actor<Req, Resp, dynamic> _actor;

  LocalActorRef._(this._actor) {
    _subscription = _controller.stream.listen((message) async {
      try {
        if (message is _Message) {
          await _actor.tell(message.payload);
        } else if (message is _Request<Req, Resp>) {
          await _actor.ask(message.payload, message.respond);
        } else {
          print("Received unsupported message type: ${message.runtimeType}");
        }
        // ignore: avoid_catches_without_on_clauses
      } catch (ex) {
        await _subscription.cancel();
        await _controller.close();
        _completer.complete(Failed(ex));
      }
    });
  }

  @internal
  static Future<LocalActorRef<Req, Resp>> start<Req, Resp>(Actor<Req, Resp, dynamic> actor, bool awaitInit) async {
    final initF = actor.init();
    if (awaitInit) await initF;
    return LocalActorRef._(actor);
  }

  @override
  Future<Resp> ask(Req message) async {
    final completer = Completer<Resp>();
    _controller.add(_Request<Req, Resp>(message, completer.complete));
    return completer.future;
  }

  @override
  Future<void> tell(Req message) async => _controller.add(_Message(message));

  @override
  Future<void> stop() async {
    await _controller.close();
    await _actor
        .stop()
        .then((_) => _completer.complete(Stopped()))
        .onError((ex, __) => _completer.complete(Failed(ex)));
  }

  @override
  LocalActorMonitor monitor() => LocalActorMonitor._(_completer.future);
}
