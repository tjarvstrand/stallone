import 'dart:async';

import 'package:stallone/stallone.dart';

class ParrotActor extends Actor {
  ParrotActor() : super(null);

  @override
  Logger get logger => IgnoreLogger();

  @override
  Future handleTell(dynamic state, dynamic message) => Future.value(message);

  @override
  Future handleAsk(dynamic state, dynamic request, void Function(dynamic) respond) async {
    respond(request);
    return request;
  }
}
