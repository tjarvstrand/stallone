import 'dart:async';

import 'package:stallone/stallone.dart';

class IntActor extends Actor<int, int, int> {
  IntActor([int initial = 0]) : super(initial);

  @override
  Future<int> handleTell(int state, int message) => Future.value(message);

  @override
  Future<int> handleAsk(int state, int message, void Function(int) respond) async {
    final res = state + message;
    respond(res);
    return res;
  }
}
