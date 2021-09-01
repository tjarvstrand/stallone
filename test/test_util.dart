Future<void> eventually(Future<void> Function() f, [Duration timeout = const Duration(seconds: 15)]) =>
    _eventually(f).timeout(timeout);

Future<void> _eventually(Future<void> Function() f) => f().onError((_, __) => f());
