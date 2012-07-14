#library('parser-test');

#import('package:unittest/unittest.dart');
#import('parser.dart');

/**
 * Parser test.
 */
void main() {
  test('decoding error packet', () {
    expect(Parser.decodePacket('7:::'), equals({
        'type': 'error'
      , 'reason': ''
      , 'advice': ''
      , 'endpoint': ''
    }));
  });

  test('decoding error packet with reason', () {
    expect(Parser.decodePacket('7:::0'), equals({
        'type': 'error'
      , 'reason': 'transport not supported'
      , 'advice': ''
      , 'endpoint': ''
    }));
  });

  test('decoding error packet with reason and advice', () {
    expect(Parser.decodePacket('7:::2+0'), equals({
        'type': 'error'
      , 'reason': 'unauthorized'
      , 'advice': 'reconnect'
      , 'endpoint': ''
    }));
  });

  test('decoding error packet with endpoint', () {
    expect(Parser.decodePacket('7::/woot'), equals({
        'type': 'error'
      , 'reason': ''
      , 'advice': ''
      , 'endpoint': '/woot'
    }));
  });

  test('decoding ack packet', () {
    expect(Parser.decodePacket('6:::140'), equals({
        'type': 'ack'
      , 'ackId': '140'
      , 'endpoint': ''
      , 'args': []
    }));
  });

  test('decoding ack packet with args', () {
    expect(Parser.decodePacket('6:::12+["woot","wa"]'), equals({
        'type': 'ack'
      , 'ackId': '12'
      , 'endpoint': ''
      , 'args': ['woot', 'wa']
    }));
  });

  test('decoding ack packet with bad json', () {
    bool thrown = false;

    try {
      expect(Parser.decodePacket('6:::1+{"++]'), equals({
          'type': 'ack'
        , 'ackId': '1'
        , 'endpoint': ''
        , 'args': []
      }));
    } catch (final e) {
      thrown = true;
    }

    expect(thrown, isFalse);
  });

  test('decoding json packet', () {
    expect(Parser.decodePacket('4:::"2"'), equals({
        'type': 'json'
      , 'endpoint': ''
      , 'data': '2'
    }));
  });

  test('decoding json packet with message id and ack data', () {
    expect(Parser.decodePacket('4:1+::{"a":"b"}'), equals({
        'type': 'json'
      , 'id': 1
      , 'ack': 'data'
      , 'endpoint': ''
      , 'data': { 'a': 'b' }
    }));
  });

  test('decoding an event packet', () {
    expect(Parser.decodePacket('5:::{"name":"woot"}'), equals({
        'type': 'event'
      , 'name': 'woot'
      , 'endpoint': ''
      , 'args': []
    }));
  });

  test('decoding an event packet with message id and ack', () {
    expect(Parser.decodePacket('5:1+::{"name":"tobi"}'), equals({
        'type': 'event'
      , 'id': 1
      , 'ack': 'data'
      , 'endpoint': ''
      , 'name': 'tobi'
      , 'args': []
    }));
  });

  test('decoding an event packet with data', () {
    expect(Parser.decodePacket('5:::{"name":"edwald","args":[{"a": "b"},2,"3"]}')
    , equals({
        'type': 'event'
      , 'name': 'edwald'
      , 'endpoint': ''
      , 'args': [{'a': 'b'}, 2, '3']
    }));
  });

  test('decoding a message packet', () {
    expect(Parser.decodePacket('3:::woot'), equals({
        'type': 'message'
      , 'endpoint': ''
      , 'data': 'woot'
    }));
  });

  test('decoding a message packet with id and endpoint', () {
    expect(Parser.decodePacket('3:5:/tobi'), equals({
        'type': 'message'
      , 'id': 5
      , 'ack': true
      , 'endpoint': '/tobi'
      , 'data': ''
    }));
  });

  test('decoding a heartbeat packet', () {
    expect(Parser.decodePacket('2:::'), equals({
        'type': 'heartbeat'
      , 'endpoint': ''
    }));
  });

  test('decoding a connection packet', () {
    expect(Parser.decodePacket('1::/tobi'), equals({
        'type': 'connect'
      , 'endpoint': '/tobi'
      , 'qs': ''
    }));
  });

  test('decoding a connection packet with query string', () {
    expect(Parser.decodePacket('1::/test:?test=1'), equals({
        'type': 'connect'
      , 'endpoint': '/test'
      , 'qs': '?test=1'
    }));
  });

  test('decoding a disconnection packet', () {
    expect(Parser.decodePacket('0::/woot'), equals({
        'type': 'disconnect'
      , 'endpoint': '/woot'
    }));
  });

  test('encoding error packet', () {
    expect(Parser.encodePacket({
        'type': 'error'
      , 'reason': ''
      , 'advice': ''
      , 'endpoint': ''
    }), equals('7::'));
  });

  test('encoding error packet with reason', () {
    expect(Parser.encodePacket({
        'type': 'error'
      , 'reason': 'transport not supported'
      , 'advice': ''
      , 'endpoint': ''
    }), equals('7:::0'));
  });

  test('encoding error packet with reason and advice', () {
    expect(Parser.encodePacket({
        'type': 'error'
      , 'reason': 'unauthorized'
      , 'advice': 'reconnect'
      , 'endpoint': ''
    }), equals('7:::2+0'));
  });

  test('encoding error packet with endpoint', () {
    expect(Parser.encodePacket({
        'type': 'error'
      , 'reason': ''
      , 'advice': ''
      , 'endpoint': '/woot'
    }), equals('7::/woot'));
  });

  test('encoding ack packet', () {
    expect(Parser.encodePacket({
        'type': 'ack'
      , 'ackId': '140'
      , 'endpoint': ''
      , 'args': []
    }), equals('6:::140'));
  });

  test('encoding ack packet with args', () {
    expect(Parser.encodePacket({
        'type': 'ack'
      , 'ackId': '12'
      , 'endpoint': ''
      , 'args': ['woot', 'wa']
    }), equals('6:::12+["woot","wa"]'));
  });

  test('encoding json packet', () {
    expect(Parser.encodePacket({
        'type': 'json'
      , 'endpoint': ''
      , 'data': '2'
    }), equals('4:::"2"'));
  });

  test('encoding json packet with message id and ack data', () {
    expect(Parser.encodePacket({
        'type': 'json'
      , 'id': 1
      , 'ack': 'data'
      , 'endpoint': ''
      , 'data': { 'a': 'b' }
    }), equals('4:1+::{"a":"b"}'));
  });

  test('encoding an event packet', () {
    expect(Parser.encodePacket({
        'type': 'event'
      , 'name': 'woot'
      , 'endpoint': ''
      , 'args': []
    }), equals('5:::{"name":"woot"}'));
  });

  test('encoding an event packet with message id and ack', () {
    expect(Parser.encodePacket({
        'type': 'event'
      , 'id': 1
      , 'ack': 'data'
      , 'endpoint': ''
      , 'name': 'tobi'
      , 'args': []
    }), equals('5:1+::{"name":"tobi"}'));
  });

  test('encoding an event packet with data', () {
    expect(Parser.encodePacket({
        'type': 'event'
      , 'name': 'edwald'
      , 'endpoint': ''
      , 'args': [{'a': 'b'}, 2, '3']
    }), equals('5:::{"name":"edwald","args":[{"a":"b"},2,"3"]}'));
  });

  test('encoding a message packet', () {
    expect(Parser.encodePacket({
        'type': 'message'
      , 'endpoint': ''
      , 'data': 'woot'
    }), equals('3:::woot'));
  });

  test('encoding a message packet with id and endpoint', () {
    expect(Parser.encodePacket({
        'type': 'message'
      , 'id': 5
      , 'ack': true
      , 'endpoint': '/tobi'
      , 'data': ''
    }), equals('3:5:/tobi'));
  });

  test('encoding a heartbeat packet', () {
    expect(Parser.encodePacket({
        'type': 'heartbeat'
      , 'endpoint': ''
    }), equals('2::'));
  });

  test('encoding a connection packet', () {
    expect(Parser.encodePacket({
        'type': 'connect'
      , 'endpoint': '/tobi'
      , 'qs': ''
    }), equals('1::/tobi'));
  });

  test('encoding a connection packet with query string', () {
    expect(Parser.encodePacket({
        'type': 'connect'
      , 'endpoint': '/test'
      , 'qs': '?test=1'
    }), equals('1::/test:?test=1'));
  });

  test('encoding a disconnection packet', () {
    expect(Parser.encodePacket({
        'type': 'disconnect'
      , 'endpoint': '/woot'
    }), equals('0::/woot'));
  });

  test('test decoding a payload', () {
    expect(Parser.decodePayload('\ufffd5\ufffd3:::5\ufffd7\ufffd3:::53d\ufffd3\ufffd0::'), equals([
        { 'type': 'message', 'data': '5', 'endpoint': '' }
      , { 'type': 'message', 'data': '53d', 'endpoint': '' }
      , { 'type': 'disconnect', 'endpoint': '' }
    ]));
  });

  test('test encoding a payload', () {
    expect(Parser.encodePayload([
        Parser.encodePacket({ 'type': 'message', 'data': '5', 'endpoint': '' })
      , Parser.encodePacket({ 'type': 'message', 'data': '53d', 'endpoint': '' })
    ]), equals('\ufffd5\ufffd3:::5\ufffd7\ufffd3:::53d'));
  });

  test('test decoding newline', () {
    expect(Parser.decodePacket('3:::\n'), equals({
        'type': 'message'
      , 'endpoint': ''
      , 'data': '\n'
    }));
  });
}
