import 'dart:async';

import 'package:stream_channel/stream_channel.dart';

class Event<T> {
  final T payload;

  Event(this.payload);
}

class Request<T> extends Event<T> {
  final int id;

  Request(this.id, T payload) : super(payload);
}

class Response<T> {
  final int requestId;
  final T payload;

  Response(this.requestId, this.payload);
}

class ResponseChannel<Req, Resp> {
  final StreamChannel _channel;
  late Stream<Event<Req>> stream;

  ResponseChannel(this._channel) {
    stream = _channel.stream.asBroadcastStream().map((event) => event as Event<Req>);
  }

  void send(Resp payload) => _channel.sink.add(Response(-1, payload));

  void respond(int requestId, Resp payload) => _channel.sink.add(Response(requestId, payload));

  Future<void> close() => _channel.sink.close();
}

class RequestChannel<Req, Resp> {
  int _nextRequestId = 0;
  final StreamChannel _channel;
  late Stream<Response> _stream;
  Stream<Resp> get stream => _stream.map((m) => m.payload);

  RequestChannel(this._channel) {
    _stream = _channel.stream.asBroadcastStream().cast<Response>();
  }

  Future<Resp> request(Req request, [Duration? timeout]) async {
    final requestId = _nextRequestId >= double.maxFinite ? 0 : _nextRequestId++;
    _channel.sink.add(Request(requestId, request));
    final r = await _stream.firstWhere((r) => r.requestId == requestId).then((r) => r.payload);
    return r;
  }

  void notify(Req message) => _channel.sink.add(Event(message));

  Future<void> close() => _channel.sink.close();
}
