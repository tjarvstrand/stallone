import 'package:flutter_test/flutter_test.dart';
import 'package:stallone/src/actor_monitor.dart';
import 'package:stallone/src/isolate_actor/isolate_actor_ref.dart';
import 'package:stallone_test_lib/stallone_test_lib.dart';

void main() {
  test('Ask and tell work as expected', () async {
    final states = <int>[];
    final ref = await IsolateActorRef.start(AdditionActor());
    ref.state.listen(states.add);
    expect(await ref.ask(1), 1);
    expect(await ref.ask(1), 2);
    ref.tell(0);
    await eventually(() async => expect(await ref.ask(0), 0));
    expect(states, [0, 1, 2, 0]);
  });

  test('Stop stops the actor', () async {
    final ref = await IsolateActorRef.start(AdditionActor());
    final monitor = ref.monitor();
    await ref.stop();
    expect(await monitor.future, (r) => r is Done);
  });

  test('Crashing stops the actor', () async {
    final ref = await IsolateActorRef.start(CrashingActor());
    final monitor = ref.monitor();
    ref.tell(Exception());
    expect(await monitor.future, (r) => r is Failed);
  });
}
