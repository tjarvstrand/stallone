part of stallone;

class LocalActorRef<Req, Resp> extends ActorRef<Req, Resp> {
  final Actor<Req, Resp, dynamic> _actor;
  LocalActorRef._(this._actor);

  static Future<LocalActorRef<Req, Resp>> _start<Req, Resp>(Actor<Req, Resp, dynamic> actor, bool awaitInit) async {
    final initF = actor._initialize();
    if (awaitInit) await initF;
    return LocalActorRef._(actor);
  }

  @override
  FutureOr<Resp> ask(Req message) async {
    final completer = Completer<Resp>();
    await _actor._handleAsk(message, completer.complete);
    return completer.future;
  }

  @override
  void tell(Req message) => _actor._handleTell(message);

  @override
  FutureOr<void> stop() => _actor._stop();
}
