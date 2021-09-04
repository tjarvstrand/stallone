import 'dart:async';

import 'package:stallone/stallone.dart';

class CrashingActor extends Actor<Exception, void, void> {
  final Exception? _initException;
  CrashingActor([this._initException]) : super(null);

  @override
  Future<void> handleInit(void _) {
    final ex = _initException;
    if (ex != null) throw ex;
    return Future.value(null);
  }

  @override
  Future<void> handleTell(void state, Exception message) => throw message;

  @override
  Future<void> handleAsk(void state, Exception message, void Function(void) respond) => throw message;
}
