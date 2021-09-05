import 'package:meta/meta.dart';

abstract class Logger {
  void finest(String msg);
  void finer(String msg);
  void fine(String msg);
  void info(String msg);
  void warning(String msg, [dynamic error, StackTrace? trace]);
  void severe(String msg, [dynamic error, StackTrace? trace]);
}

enum LogLevel { finest, finer, fine, info, warning, severe }

extension LogLevelString on LogLevel {
  String get name {
    switch (this) {
      case LogLevel.finest:
        return "FINEST";
      case LogLevel.finer:
        return "FINER";
      case LogLevel.fine:
        return "FINE";
      case LogLevel.info:
        return "INFO";
      case LogLevel.warning:
        return "WARNING";
      case LogLevel.severe:
        return "SEVERE";
    }
  }
}

class PrintLogger implements Logger {
  final bool logStackTrace;
  final LogLevel level;

  PrintLogger([this.level = LogLevel.warning, this.logStackTrace = true]);

  @override
  void finest(String msg) => log(LogLevel.finest, msg);
  @override
  void finer(String msg) => log(LogLevel.finer, msg);
  @override
  void fine(String msg) => log(LogLevel.fine, msg);
  @override
  void info(String msg) => log(LogLevel.info, msg);
  @override
  void warning(String msg, [dynamic error, StackTrace? trace]) =>
      log(LogLevel.warning, "$msg${_formatError(error, trace)}");
  @override
  void severe(String msg, [dynamic error, StackTrace? trace]) =>
      log(LogLevel.severe, "$msg${_formatError(error, trace)}");

  String _formatError(dynamic error, StackTrace? trace) =>
      "${error == null ? "" : ": $error"}${logStackTrace && trace != null ? "\n$trace" : ""}";

  @protected
  void log(LogLevel level, String msg) {
    // ignore: avoid_print
    if (level.index >= this.level.index) print("${level.name}: $msg");
  }
}

class IgnoreLogger implements Logger {
  @override
  void finest(String msg) {}
  @override
  void finer(String msg) {}
  @override
  void fine(String msg) {}
  @override
  void info(String msg) {}
  @override
  void warning(String msg, [dynamic error, StackTrace? trace]) {}
  @override
  void severe(String msg, [dynamic error, StackTrace? trace]) {}
}
