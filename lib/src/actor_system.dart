import 'actor.dart';
import 'isolate_actor_ref.dart';
import 'local_actor_ref.dart';

class ActorSystem {
  Future<ActorRef> start<Req, Resp>(
    Actor<Req, Resp, dynamic> actor, {
    bool awaitInit = true,
    bool threadLocal = false,
  }) =>
      threadLocal ? LocalActorRef.start(actor, awaitInit) : IsolateActorRef.start(actor, awaitInit);
}
