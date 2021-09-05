import 'dart:async';
import 'dart:collection';

import 'package:rxdart/rxdart.dart';

abstract class MailBox {
  Future<dynamic> get next;
  Future<void> close();
  void addControl(dynamic message);
  void addOther(dynamic message);
}

class DefaultMailBox extends MailBox {
  // We will never be waiting on new messages when adding using addControl and addOther since they are only callable
  // from within the actor itself.
  bool _isWaiting = false;
  final _control = Queue();
  final _other = Queue();
  late List<StreamSubscription> _subscriptions;
  late Stream _stream;
  DefaultMailBox(Stream control, Stream other) {
    _subscriptions = [
      control.listen((m) => !_isWaiting ? _control.add(m) : null),
      other.listen((m) => !_isWaiting ? _other.add(m) : null),
    ];
    _stream = Rx.merge([control, other]).asBroadcastStream();
  }

  @override
  Future<dynamic> get next async {
    if (_control.isNotEmpty) {
      return _control.removeFirst();
    } else if (_other.isNotEmpty) {
      return _other.removeFirst();
    } else {
      _isWaiting = true;
      final next = await _stream.first;
      _isWaiting = false;
      return next;
    }
  }

  @override
  Future<void> close() => Future.wait(_subscriptions.map((s) => s.cancel()));

  @override
  void addControl(dynamic message) => _control.add(message);

  @override
  void addOther(dynamic message) => _other.add(message);
}
