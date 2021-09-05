abstract class ControlMessage {}

abstract class ControlResponse {}

class Stop extends ControlMessage {}

class Stopped extends ControlResponse {}

class InitComplete extends ControlResponse {}
