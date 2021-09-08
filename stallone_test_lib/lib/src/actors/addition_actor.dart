import 'dart:async';

import 'package:stallone/stallone.dart';

class AdditionActor extends Actor<int, int, int> {
  AdditionActor([int initial = 0]) : super(initial);

  @override
  // Logger get logger => PrintLogger(LogLevel.finest);
  Logger get logger => IgnoreLogger();

  @override
  Future<void> handleTell(int message) async {
    logger.info("tell $message, state: $state");
    state = message;
  }

  @override
  Future<void> handleAsk(int request, void Function(int) respond) async {
    logger.info("ask $request, state: $state");
    final res = state + request;
    respond(res);
    state = res;
  }
}
