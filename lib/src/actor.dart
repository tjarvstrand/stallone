part of stallone;

abstract class ActorRef<Req, Resp> {
  void tell(Req message);
  FutureOr<Resp> ask(Req message);
  FutureOr<void> stop();
}

abstract class Actor<Req, Resp, State> {
  State _state;
  Actor(this._state);

  FutureOr<State> _handleTell(Req message) async => _state = await handleTell(_state, message);
  FutureOr<State> handleTell(State state, Req message) => state;
  FutureOr<State> _handleAsk(Req request, void Function(Resp) respond) async =>
      _state = await handleAsk(_state, request, respond);
  FutureOr<State> handleAsk(State state, Req request, void Function(Resp) respond) => state;
  FutureOr<State> _initialize() async => _state = await initialize(_state);
  FutureOr<State> initialize(State state) => state;

  FutureOr<void> _stop() => stop(_state);
  FutureOr<void> stop(State state) {}
}
