library namespace;

import 'manager.dart';
import 'socket.dart';
import 'store.dart';

class SocketNamespace {
  Manager _manager;
  String _name;
  Map<String, Socket> _sockets;
  Function _auth;

  SocketNamespace(this._manager, [this._name = '']) {
    _sockets = new Map<String, Socket>();
    _auth = false;
  }

  Logger get log => _manager.log;
  Store get store => _manager.store;

  Socket get json {
    _flags.json = true;
    return this;
  }

  Socket get volatile {
    _flags.volatile = true;
    return this;
  }

  set in(String room) =>
  set except(String id)
  set flags(Map flags) =>
  set authorization(Function fn) => _auth = fn;

  /**
   * Sends out a packet.
   */
  SocketNamespace _packet(Packet packet) {
  }

  /**
   * Sends to everyone.
   */
  Packet send(Map data) {
  }

  /**
   * Emits to everyone.
   */
  Packet emit(String name) {
  }

  /**
   * Retrieves or creates a write-only socket for a client, unless specified.
   *
   * @param {Boolean} whether the socket will be readable when initialized
   */
  Socket socket(String sid, [bool readable = false]) {
    if (!_sockets.containsKey(sid)) {
      _sockets[sid] = new Socket(_manager, sid, this, readable);
    }
    return _sockets[sid];
  }

  /**
   * Called when a socket disconnects entirely.
   */
  _handleDisconnect(String sid, reason, raiseOnDisconnect) {
  }

  SocketNamespace _authorize(data, callback) {
  }

  /**
   * Handles a packet.
   */
  void handlePacket(String sessid, Packet packet) {
    Socket socket = socket(sessid);
    bool dataAck = packet.ack == 'data';

    ack = () {
      log.debug('sending data ack packet');
      socket.packet({
        'type': 'ack',
        'args': args,
        'ackId': packet.id
      })
    }

    error = (String err) {
      log.warn('hanshake error $err for $_name');
      socket.packet({ 'type': 'error', 'reason': err });
    }

    connect = () {
      _manager.onJoin(sessid, _name);
      store.publish('join', sessid, _name);

      // packet echo
      socket.packet({ 'type': 'connect' });

      _emit('connection', socket);
    }

    switch (packet.type) {
      case 'connect':
        if (packet.endpoint == '') {
          connect();
        } else {
          Object handshakeData = _manager.handshaken[sessid];

          authorize(handshakeData, (err, authorized, newData) {
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
          log.debug('ignoring blacklisted event `${packet.name}`');
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
