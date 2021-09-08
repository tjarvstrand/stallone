import 'dart:async';

import 'package:stallone/stallone.dart';

class ParrotActor extends Actor {
  ParrotActor() : super(null);

  @override
  Logger get logger => IgnoreLogger();

  @override
  Future<void> handleTell(dynamic message) => Future.value(message);

  @override
  Future<void> handleAsk(dynamic request, void Function(dynamic) respond) async {
    respond(request);
    return request;
  }
}
