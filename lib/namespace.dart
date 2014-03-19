library namespace;

import 'manager.dart';
import 'parser.dart';
import 'socket.dart';
import 'store.dart';

import 'package:logging/logging.dart';

class SocketNamespace extends EventEmitter {
  Manager _manager;
  String _name;
  Map<String, Socket> _sockets;
  Map<String, Object> _flags;
  Function _auth;

  SocketNamespace(this._manager, [this._name = '']) :
    _sockets = new Map<String, Socket>() {
    setFlags();
  }

  Logger get log => _manager.log;
  Store get store => _manager.store;

  SocketNamespace get json {
    _flags['json'] = true;
    return this;
  }

  SocketNamespace get volatile {
    _flags['volatile'] = true;
    return this;
  }

  set to(String room) {
    _flags['endpoint'] = '_name${room != null ? '/$room' : ''}';
  }

  /**
   * Adds a session id we should prevent relaying messages to (flag).
   */
  set except(String id) {
    _flags['exceptions'].addLast(id);
  }

  /**
   * Sets the default flags.
   */
  setFlags() {
    _flags = {
      'endpoint': _name,
      'exceptions': []
    };
  }

  set authorization(Function fn) => _auth = fn;

  /**
   * Sends out a packet.
   */
  _packet(Packet packet) {
    packet.endpoint = this.name;

    var volatile = this.flags.volatile;
    var exceptions = this.flags.exceptions;
    var packet = Parser.encodePacket(packet);

    _manager.onDispatch(_flags['endpoint'], packet, _flags['volatile'], exceptions);
    store.publish('dispatch', this.flags.endpoint, packet, volatile, exceptions);

    setFlags();
  }

  /**
   * Sends to everyone.
   */
  send(Map data) => _packet({
    'type': _flags.json ? 'json' : 'message',
    'data': data
  });

  /**
   * Emits to everyone.
   */
  emit(String name) {
    if (name == 'newListener') {
      return this.$emit.apply(this, arguments);
    }

    return _packet({
      'type': 'event',
      'name': name,
      'args': util.toArray(arguments).slice(1)
    });
  }

  /**
   * Retrieves or creates a write-only socket for a client, unless specified.
   *
   * @param {Boolean} whether the socket will be readable when initialized
   */
  Socket socket(String sid, [bool readable = false]) {
    return _sockets.putIfAbsent(sid, () {
      new Socket(_manager, sid, this, readable);
    });
  }

  /**
   * Called when a socket disconnects entirely.
   */
  _handleDisconnect(String sid, reason, bool raiseOnDisconnect) {
    if (_sockets.containsKey(sid) && _sockets[sid].readable) {
      if (raiseOnDisconnect) {
        _sockets[sid].onDisconnect(reason);
      }
      _sockets.remove(sid);
    }
  }

  _authorize(data, callback(Function error, bool authorized, [data])) {
    if (_auth != null) {
      _auth(data, (err, authorized) {
        log.fine('client ' + (authorized ? '' : 'un') + 'authorized for $name');
        callback(err, authorized);
      });
    } else {
      log.fine('client authorized for $name');
      callback(null, true);
    }
  }

  /**
   * Handles a packet.
   */
  handlePacket(String sessid, Packet packet) {
    Socket socket = this.socket(sessid);
    bool dataAck = packet.ack == 'data';

    var ack = () {
      log.fine('sending data ack packet');
      socket.packet({
        'type': 'ack',
        'args': args,
        'ackId': packet.id
      });
    };

    var error = (String err) {
      log.warning('hanshake error $err for $_name');
      socket.packet({ 'type': 'error', 'reason': err });
    };

    var connect = () {
      _manager.onJoin(sessid, _name);
      store.publish('join', sessid, _name);

      // packet echo
      socket.packet({ 'type': 'connect' });

      _emit('connection', socket);
    };

    switch (packet.type) {
      case 'connect':
        if (packet.endpoint == '') {
          connect();
        } else {
          Object handshakeData = _manager.handshaken[sessid];

          _authorize(handshakeData, (err, authorized, newData) {
            if (err != null) {
              return error(err);
            }

            if (authorized) {
              Map data = new Map.from(newData);
              _manager.onHandshake(sessid, data);
              store.publish('handshake', sessid, data);
              connect();
            } else {
              error('unauthorized');
            }
          });
        }
        break;

      case 'ack':
        if (socket._acks.containsKey(packet.ackId)) {
          socket._acks[packet.ackId](socket, packet.args);
        } else {
          log.info('unknown ack packet');
        }
        break;

      case 'event':
        if (_manager.get('blacklist').indexOf(packet.name)) {
          log.fine('ignoring blacklisted event `${packet.name}`');
        } else {
          List params = packet.args;

          if (dataAck) {
            params.add(ack);
          }

          socket._emit(packet.name, params);
        }
        break;

      case 'disconnect':
        _manager.onLeave(sessid, _name);
        store.publish('leave', sessid, _name);

        socket._emit('disconnect', packet.reason != null ? packet.reason : 'packet');
        break;

      case 'json':
      case 'message':
        List params = [packet.data];

        if (dataAck) {
          params.add(ack);
        }

        socket._emit('message', params);
        break;
    }
  }
}
