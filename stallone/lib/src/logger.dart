import 'package:meta/meta.dart';

abstract class Logger {
  void fine(String msg);
  void info(String msg);
  void warning(String msg, [dynamic error, StackTrace? trace]);
  void severe(String msg, [dynamic error, StackTrace? trace]);
}

enum LogLevel { fine, info, warning, severe }

extension LogLevelString on LogLevel {
  String get name {
    switch (this) {
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

class DefaultLogger implements Logger {
  final LogLevel level;

  DefaultLogger([this.level = LogLevel.warning]);

  @override
  void fine(String msg) => log(LogLevel.fine, msg);
  @override
  void info(String msg) => log(LogLevel.info, msg);
  @override
  void warning(String msg, [dynamic error, StackTrace? trace]) =>
      log(LogLevel.warning, "$msg${error == null ? "" : "\n$error"}${trace == null ? "" : "\n$trace"}");
  @override
  void severe(String msg, [dynamic error, StackTrace? trace]) =>
      log(LogLevel.severe, "$msg${error == null ? "" : "\n$error"}${trace == null ? "" : "\n$trace"}");

  @protected
  void log(LogLevel level, String msg) {
    // ignore: avoid_print
    if (level.index >= this.level.index) print("${level.name}: $msg");
  }
}

class IgnoreLogger implements Logger {
  @override
  void fine(String msg) {}
  @override
  void info(String msg) {}
  @override
  void warning(String msg, [dynamic error, StackTrace? trace]) {}
  @override
  void severe(String msg, [dynamic error, StackTrace? trace]) {}
}
