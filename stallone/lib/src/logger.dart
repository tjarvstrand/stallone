import 'package:meta/meta.dart';

abstract class Logger {
  void fine(String msg);
  void info(String msg);
  void warning(String msg, [dynamic error, StackTrace trace]);
  void severe(String msg, [dynamic error, StackTrace trace]);
}

enum LogLevel { fine, info, warning, severe }

class DefaultLogger implements Logger {
  final LogLevel level;

  DefaultLogger([this.level = LogLevel.warning]);

  @override
  void fine(String msg) => log(LogLevel.fine, msg);
  @override
  void info(String msg) => log(LogLevel.info, msg);
  @override
  void warning(String msg, [dynamic error, StackTrace? trace]) => log(LogLevel.warning, "$msg\n$error\n$trace");
  @override
  void severe(String msg, [dynamic error, StackTrace? trace]) => log(LogLevel.severe, "$msg\n$error\n$trace");

  @protected
  void log(LogLevel level, String msg) =>
      // ignore: avoid_print
      level.index >= this.level.index ? print("${level.toString().toUpperCase()}: $msg") : null;
}
