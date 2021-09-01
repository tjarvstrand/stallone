import 'dart:async';

import 'package:stallone/stallone.dart';
import 'package:test/test.dart';

import 'test_util.dart';

class IntActor extends Actor<int, int, int> {
  IntActor([int initial = 0]) : super(initial);

  @override
  FutureOr<int> handleTell(int state, int message) => message;

  @override
  FutureOr<int> handleAsk(int state, int message, void Function(int) respond) async {
    final res = state + message;
    respond(res);
    return res;
  }

  @override
  FutureOr<void> stop(int _) {
    print("stopping");
  }
}

void main() {
  final system = ActorSystem();

  test('Ask and tell work as expected', () async {
    final ref = await system.start(IntActor());
    expect(await ref.ask(1), 1);
    expect(await ref.ask(1), 2);
    ref.tell(0);
    await eventually(() async => expect(await ref.ask(1), 1));
  });

  test('Stop stops the actor', () async {
    // fixme
    final ref = await system.start(IntActor());
    await ref.stop();
  });
}
