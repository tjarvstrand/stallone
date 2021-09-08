import 'dart:async';
import 'dart:collection';

import 'package:collection/collection.dart';
import 'package:rxdart/rxdart.dart';

abstract class MailBox {
  Future<dynamic> get next;
  Future<void> close();
  void addControl(dynamic message);
  void addOther(dynamic message);
}

// A 1-tiered mailbox.
class DefaultMailBox extends NTieredMailBox {
  DefaultMailBox(Stream control, Stream other) : super(control, other, 1, (_) => 1);
}

class NTieredMailBox extends MailBox {
  // We will never be waiting on new messages when adding using addControl and addOther since they are only callable
  // from within the actor itself.
  bool _isWaiting = false;
  final int tiers;
  final _control = Queue();
  late List<Queue> _queues;
  late List<StreamSubscription> _subscriptions;
  late Stream _stream;
  final int Function(dynamic) _discriminator;
  final StreamController _internal = StreamController();
  NTieredMailBox(Stream control, Stream other, this.tiers, this._discriminator) {
    if (tiers < 1) {
      throw ArgumentError("Must have a positive number of tiers");
    }
    _queues = List.generate(tiers, (_) => Queue());
    _subscriptions = [
      control.listen((m) => !_isWaiting ? _control.add(m) : null),
      other.listen((m) {
        if (!_isWaiting) {
          _queues[_discriminator(m).clamp(0, tiers - 1)].add(m);
        }
      }),
    ];
    _stream = Rx.merge([_internal.stream, control, other]).asBroadcastStream();
  }

  @override
  Future<dynamic> get next async {
    if (_control.isNotEmpty) {
      return _control.removeFirst();
    } else {
      final queue = _queues.firstWhereOrNull((q) => q.isNotEmpty);
      if (queue != null) {
        return queue.removeFirst();
      } else {
        _isWaiting = true;
        final next = await _stream.first;
        _isWaiting = false;
        return next;
      }
    }
  }

  @override
  Future<void> close() async {
    await _internal.close();
    await Future.wait(_subscriptions.map((s) => s.cancel()));
  }

  @override
  void addControl(dynamic message) {
    if (_isWaiting) {
      _internal.add(message);
    } else {
      _control.add(message);
    }
  }

  @override
  void addOther(dynamic message) {
    if (_isWaiting) {
      _internal.add(message);
    } else {
      _queues[_discriminator(message).clamp(0, tiers - 1)].add(message);
    }
  }
}
