library socket;

import 'dart:io';
import 'manager.dart';
import 'namespace.dart';

abstract class Event { }

typedef void EventListener(Event event);

abstract class EventListenerList {
  EventListenerList add(EventListener handler, [bool useCapture]);

  EventListenerList remove(EventListener handler, [bool useCapture]);

  bool dispatch(Event evt);
}

abstract class SocketEvents extends Event {
  EventListenerList get event;
}

abstract class Socket {
}

class _Socket {
  //WebSocketHandler _handler;
  String _id;
  SocketNamespace _namespace;
  Manager _manager;
  bool _readable;
  bool _disconnected;
  int _ackPackets;
  Map<int, Function> _acks;

  _Socket(this._manager, this._id, this._namespace, this._readable) {
    _disconnected = false;
    _ackPackets = 0;
    _acks = new Map<int, Function>();
    _manager.store.client(_id);
  }

  get handshake => _manager.handshaken[_id];
  get manager => _manager.transports[_id].name;
  get log => _manager.log;
  get json => _flags.json = true;
  get volatile => _flags.volatile = true;
  get broadcast =>  _flags.broadcast = true;

  set to(String room) => _flags.room = room;
  set flags(Flags flags) {
    _flags = {
      'endpoint': _namespace.name,
      'room': ''
    };
  }

  /**
   * Triggered on disconnect.
   */
  _onDisconnect(reason) {
    if (!_disconnected) {
      _emit('disconnected', reason);
      _disconnected = true;
    }
  }

  /**
   * Joins user to a room.
   */
  Socket join(String name) {
    name = '${_namespace.name}/${name}';
    _manager.onJoin(_id, name);
    _manager.store.publish('join', _id, name);
    return this;
  }

  /**
   * Un-joins a user from a room.
   */
  Socket leave(String name) {
    name = '${_namespace.name}/${name}';
    _manager.onLeave(_id, name);
    _manager.store.publish('join', _id, name);
    return this;
  }

  /**
   * Transmits a packet.
   */
  Socket _packet(Map packet) {
    if (_flags.broadcast) {
      _namespace.in(_flags.room).except(_id).packet(packet);
    } else {
      packet.endpoint = _flags.endpoint;
      packet = parser.encodePacket(packet);

      _dispatch(packet, _flags.volatile);
    }
    _setFlags();
    return this;
  }

  _dispatch(Object packet, bool volatile) {
    if (_manager.transports[_id] && _manager.transports[_id].open) {
      _manager.transports[_id].onDispatch(packet, volatile);
    } else {
      if (!volatile) {
        _manager.onClientDispatch(_id, packet, volatile);
      }
      _manager.store.publish('dispatch:$_id', packet, volatile);
    }
  }

  /**
   * Kicks client.
   */
  Socket disconnect() {
    if (!_disconnected) {
      if (identical(_namespace.name, '')) {
        if (_manager.transports[_id] && _manager.transports[_id].open) {
          _manager.transports[_id].onForcedDisconnect();
        }
        _manager.onClientDisconnect(_id);
        _manager.store.publish('disconnect:$_id');
      } else {
        _packet({ 'type': 'disconnect' });
        _manager.onLeave(_id, _namespace.name);
        _emit('disconnect', 'booted');
      }
    }
    return this;
  }

  /**
   * Send a message.
   */
  Socket send(Object data, [Function ack = null]) {
    Map packet = {
      'type': _flags.json ? 'json' : 'message',
      'data': data
    };

    if (fn != null) {
      packet.id = ++_ackPackets;
      packet.ack = true;
      _acks[packet.id] = ack;
    }

    return _packet(packet);
  }

  emit(String event, data) {
  }

  /*Socket() {*/
    /*_handler = new WebSocketHandler();*/
    /*_handler.onOpen = (WebSocketConnection conn) {*/
      /*conn.onMessage*/
      /*conn.onClosed = (status, reason) {*/
        /*if (!_disconnected) {*/
          /*// emit disconnected event;*/
          /*_disconnected = true;*/
        /*}*/
      /*}*/
    /*}*/
  /*}*/

}
