part of stallone;

class ActorSystem {
  Future<ActorRef> start<Req, Resp>(
    Actor<Req, Resp, dynamic> actor, {
    bool awaitInit = true,
    bool threadLocal = false,
  }) =>
      threadLocal ? LocalActorRef._start(actor, awaitInit) : IsolateActorRef._start(actor, awaitInit);
}
