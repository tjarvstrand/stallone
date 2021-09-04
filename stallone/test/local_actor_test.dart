import 'package:pedantic/pedantic.dart';
import 'package:stallone/src/actor_monitor.dart';
import 'package:stallone/src/local_actor/local_actor_ref.dart';
import 'package:test/test.dart';

import 'actors/addition_actor.dart';
import 'actors/crashing_actor.dart';
import 'test_util.dart';

void main() {
  test('Ask and tell work as expected', () async {
    final states = <int>[];
    final ref = await LocalActorRef.start(AdditionActor());
    ref.stream.listen(states.add);
    expect(await ref.ask(1), 1);
    expect(await ref.ask(1), 2);
    unawaited(ref.tell(0));
    await eventually(() async => expect(await ref.ask(0), 0));
    expect(states, [0, 1, 2, 0]);
  });

  test('Stop stops the actor', () async {
    final ref = await LocalActorRef.start(AdditionActor());
    final monitor = ref.monitor();
    await ref.stop();
    expect(await monitor.future, (r) => r is Done);
  });

  test('Crashing stops the actor', () async {
    final ref = await LocalActorRef.start(CrashingActor());
    final monitor = ref.monitor();
    unawaited(ref.tell(Exception()));
    expect(await monitor.future, (r) => r is Failed);
  });
}
