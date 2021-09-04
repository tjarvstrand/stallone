import 'dart:async';

import 'package:stallone/stallone.dart';

class ParrotActor extends Actor {
  ParrotActor() : super(null);

  @override
  Future handleTell(dynamic state, dynamic message) => Future.value(message);

  @override
  Future handleAsk(dynamic state, dynamic message, void Function(dynamic) respond) async {
    respond(message);
    return message;
  }
}
