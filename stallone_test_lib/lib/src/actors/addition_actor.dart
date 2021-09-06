import 'dart:async';

import 'package:stallone/stallone.dart';

class AdditionActor extends Actor<int, int, int> {
  AdditionActor([int initial = 0]) : super(initial);

  @override
  // Logger get logger => PrintLogger(LogLevel.finest);
  Logger get logger => IgnoreLogger();

  @override
  Future<int> handleTell(int state, int message) async {
    logger.info("tell $message, state: $state");
    return message;
  }

  @override
  Future<int> handleAsk(int state, int request, void Function(int) respond) async {
    logger.info("ask $request, state: $state");
    final res = state + request;
    respond(res);
    return res;
  }
}
