import 'dart:isolate';

import 'package:flutter_isolate/flutter_isolate.dart';
import 'package:stallone/stallone.dart';

class _IsolateWrapper extends Isolate {
  final FlutterIsolate _inner;
  _IsolateWrapper(this._inner)
      : super(
          _inner.controlPort!,
          pauseCapability: _inner.pauseCapability!,
          terminateCapability: _inner.terminateCapability!,
        );
}

abstract class FlutterActorRef<Req, Resp, State> {
  static Future<IsolateActorRef<Req, Resp, State>> start<Req, Resp, State>(
    Actor<Req, Resp, State> actor, [
    bool awaitInit = true,
  ]) =>
      IsolateActorRef.start(actor, awaitInit, (p, z) async => _IsolateWrapper(await FlutterIsolate.spawn(p, z)));
}
