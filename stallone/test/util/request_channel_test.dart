import 'package:stallone/src/util/request_channel.dart';
import 'package:stream_channel/stream_channel.dart';
import 'package:test/test.dart';

void main() {
  test('RequestChannel.request', () async {
    final channelController = StreamChannelController();
    final responseChannel = ResponseChannel<int, int>(channelController.foreign);
    responseChannel.stream.listen((request) {
      responseChannel.respond((request as Request).id, request.payload + 1);
    });
    final requestChannel = RequestChannel<int, int>(channelController.local);
    expect(await requestChannel.request(0), 1);
    expect(await requestChannel.request(1), 2);

    await channelController.local.sink.close();
    await channelController.foreign.sink.close();
  });
}
