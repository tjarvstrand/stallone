import 'package:stallone/stallone.dart';
import 'package:test/test.dart';

import 'actors/crashing_actor.dart';
import 'actors/int_actor.dart';
import 'test_util.dart';

void main() {
  final system = ActorSystem();

  test('Ask and tell work as expected', () async {
    final ref = await system.start(IntActor(), threadLocal: true);
    expect(await ref.ask(1), 1);
    expect(await ref.ask(1), 2);
    ref.tell(0);
    await eventually(() async => expect(await ref.ask(0), 0));
  });

  test('Stop stops the actor', () async {
    final ref = await system.start(IntActor(), threadLocal: true);
    final monitor = ref.monitor();
    await ref.stop();
    expect(await monitor.future, Stopped());
  });

  test('Crashing stops the actor', () async {
    final ref = await system.start(CrashingActor(), threadLocal: true);
    final monitor = ref.monitor();
    ref.tell(Exception());
    expect(await monitor.future, (r) => r is Failed);
  });
}
