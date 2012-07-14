#library('parser');

#import('dart:json');

class Parser {

  static final packets = const <String, int> {
      'disconnect': 0,
      'connect': 1,
      'heartbeat': 2,
      'message': 3,
      'json': 4,
      'event': 5,
      'ack': 6,
      'error': 7,
      'noop': 8
    };
  static final reasons = const <String, int> {
      'transport not supported': 0,
      'client not handshaken': 1,
      'unauthorized': 2
    };
  static final advice = const <String, int> {
      'reconnect': 0
    };

  static String encodePacket(Map packet) {
    String type = packets[packet['type']];
    String id = packet['id'] != null ? packet['id'] : '';
    String endpoint = packet['endpoint'] != null ? packet['endpoint'] : '';
    String ack = packet['ack'] != null ? packet['ack']: '';
    String data = null;

    switch (packet['type']) {
      case 'message':
        if (packet['data'] != '' && !packet['data'].isEmpty())
          data = packet['data'];
        break;

      case 'event':
        Map event = { 'name': packet['name'] };
        if (packet['args'] != null && packet['args'].length > 0) {
          event['args'] = packet['args'];
        }
        data = JSON.stringify(event);
        break;

      case 'json':
        data = JSON.stringify(packet['data']);
        break;

      case 'ack':
        String args = '';
        if (packet['args'] != null && packet['args'].length > 0)
          args = "+${JSON.stringify(packet['args'])}";
        data = "${packet['ackId']}$args";
        break;

      case 'connect':
        if (packet['qs'] != null && !packet['qs'].isEmpty())
          data = packet['qs'];
        break;

      case 'error':
        String reason = reasons[packet['reason']],
               adv    = advice[packet['advice']];
        if (reason != null || adv != null)
          data = "$reason${adv != null ? "+$adv" : ''}";

        break;
    }

    // construct packet with required fragments
    var encoded = new StringBuffer();

    encoded.add("$type:$id");
    if (ack == 'data')
      encoded.add('+');
    encoded.add(":$endpoint");

    // data fragment is optional
    if (data != null)
      encoded.add(":$data");

    return encoded.toString();
  }

  /**
   * Encodes multiple messages (payload)
   */
  static String encodePayload(List<String> packets) {
    if (packets.length == 1)
      return packets[0];

    var decoded = new StringBuffer();
    packets.forEach((p) => decoded.add('\ufffd${p.length}\ufffd$p'));
    return decoded.toString();
  }

  static final RegExp regexp = const RegExp(@'([^:]+):([0-9]+)?(\+)?:([^:]+)?:?([\s\S]*)?');

  static final packetslist = const <String> [
      'disconnect',
      'connect',
      'heartbeat',
      'message',
      'json',
      'event',
      'ack',
      'error',
      'noop'
    ];
  static final reasonslist = const <String> [
      'transport not supported',
      'client not handshaken',
      'unauthorized'
    ];
  static final advicelist = const <String> [
      'reconnect'
    ];

  static Packet decodePacket(String string) {
    Match match = regexp.firstMatch(string);

    String data = match[5] != null ? match[5] : '';
    Map packet = {
      'type': packetslist[Math.parseInt(match[1])],
      'endpoint': match[4] != null ? match[4] : ''
    };

    // whether we need to acknowledge the packet
    if (match[2] != null) {
      packet['id'] = Math.parseInt(match[2]);
      if (match[3] != null)
        packet['ack'] = 'data';
      else
        packet['ack'] = true;
    }

    // handle different packet types
    switch (packet['type']) {
      case 'message':
        packet['data'] = data;
        break;

      case 'event':
        var json = JSON.parse(data);
        if (json != null) {
          packet['name'] = json['name'];
          packet['args'] = json['args'];
        }
        packet['args'] = packet['args'] != null ? packet['args'] : [];
        break;

      case 'json':
        packet['data'] = JSON.parse(data);
        break;

      case 'connect':
        packet['qs'] = data;
        break;

      case 'ack':
        match = (new RegExp(@'^([0-9]+)(\+)?(.*)')).firstMatch(data);
        if (match != null) {
          packet['ackId'] = match[1];
          packet['args'] = [];

          if (match[3] != null && !match[3].isEmpty()) {
            packet['args'] = JSON.parse(match[3]);
          }
        }
        break;

      case 'error':
        match = (new RegExp(@'([0-9]+)?(\+)?([0-9]+)?')).firstMatch(data);
        if (match != null) {
          packet['reason'] = '';
          if (match[1] != null)
            packet['reason'] = reasonslist[Math.parseInt(match[1])];
          packet['advice'] = '';
          if (match[3] != null)
            packet['advice'] = advicelist[Math.parseInt(match[3])];
        }
        break;
    }

    return packet;
  }

  /**
   * Decodes data payload. Detects multiple messages
   *
   * @return messages
   */
  static List<Packet> decodePayload(String data) {
    if (data == null)
      return [];

    if (data[0] == '\ufffd') {
      List<Map> ret = new List<Map>();

      var length = new StringBuffer();
      for (var i = 1; i < data.length; i++) {
        if (data[i] == '\ufffd') {
          var l = Math.parseInt(length.toString());
          ret.add(decodePacket(data.substring(i + 1, i + l + 1))); 
          i += l + 1;
          length.clear();
        } else {
          length.add(data[i]);
        }
      }

      return ret;
    } else {
      return [decodePacket(data)];
    }
  }

}
