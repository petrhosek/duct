library parser;

import 'dart:json';

class Parser {
  
  /// Protocol version
  static const int protocol = 1;
  
  /// Protocol version
  static final types = [
    'CONNECT',
    'DISCONNECT',
    'EVENT',
    'ACK',
    'ERROR'
  ];
  
  /// Packet type `connect`
  static const int CONNECT = 0;
  /// Packet type `disconnect`
  static const int DISCONNECT = 1;
  /// Packet type `event`
  static const int EVENT = 2;
  /// Packet type `ack`
  static const int ACK = 3;
  /// Packet type `error`
  static const int ERROR = 4;
  
  static String encode(obj) {
    var str = '';
    var nsp = false;

    // first is type
    str += obj.type;

    // if we have a namespace other than `/`
    // we append it followed by a comma `,`
    if (obj.nsp && '/' != obj.nsp) {
      nsp = true;
      str += obj.nsp;
    }

    // immediately followed by the id
    if (null != obj.id) {
      if (nsp) {
        str += ',';
        nsp = false;
      }
      str += obj.id;
    }

    // json data
    if (null != obj.data) {
      if (nsp) str += ',';
      str += stringify(obj.data);
    }

    debug('encoded %j as %s', obj, str);
    return str;
  }
  
  static Map decode(String str) {
    var p = {};
    var i = 0;

    // look up type
    p.type = int.parse(str[0]);
    if (null == types[p.type]) return error();

    // look up namespace (if any)
    if ('/' == str[i + 1]) {
      p.nsp = '';
      while (++i) {
        var c = str[i];
        if (',' == c) break;
        p.nsp += c;
        if (i + 1 == str.length) break;
      }
    } else {
      p.nsp = '/';
    }

    // look up id
    var next = str[i + 1];
    if ('' != next && int.parse(next) == next) {
      p.id = '';
      while (++i) {
        var c = str[i];
        if (null == c || int.parse(c) != c) {
          --i;
          break;
        }
        p.id += str[i];
        if (i + 1 == str.length) break;
      }
      p.id = int.parse(p.id);
    }

    // look up json data
    if (str[++i]) {
      try {
        p.data = parse(str.substring(i));
      } on FormatException catch(e){
        return error();
      }
    }

    debug('decoded %s as %j', str, p);
    return p;
  }
  
  static Map error(data) {
    return {
      'type': ERROR,
      'data': 'parser error'
    };
  }

}
