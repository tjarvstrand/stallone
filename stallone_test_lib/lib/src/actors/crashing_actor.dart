import 'dart:async';

import 'package:stallone/stallone.dart';

class CrashingActor extends Actor<Exception, void, void> {
  final Exception? _initException;
  CrashingActor([this._initException]) : super(null);

  @override
  // Logger get logger => PrintLogger(LogLevel.finer);
  Logger get logger => IgnoreLogger();

  @override
  Future<void> handleInit() {
    final ex = _initException;
    if (ex != null) throw ex;
    return Future.value(null);
  }

  @override
  Future<void> handleTell(Exception message) => throw message;

  @override
  Future<void> handleAsk(Exception request, void Function(void) respond) => throw request;
}
