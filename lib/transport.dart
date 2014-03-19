library transport;

import 'manager.dart';
import 'parser.dart';
import 'socket.dart';
import 'store.dart';

import 'dart:io';
import 'dart:isolate';
import 'package:logging/logging.dart';

class TransportEvents extends Events {
  EventListenerList get connect => this['connect'];
  EventListenerList get end => this['end'];
  EventListenerList get close => this['close'];
  EventListenerList get error => this['error'];
  EventListenerList get drain => this['drain'];

  EventListenerList operator[](String type) {
    super();
  }
}

class TransportState {
  static final values = <TransportState>[CLOSED, CLOSING, OPEN, OPENING];

  static final CLOSED = const TransportState._();
  static final CLOSING = const TransportState._();
  static final OPEN = const TransportState._();
  static final OPENING = const TransportState._();

  const TransportState._();
}

abstract class Transport {
  const int OPENING = 0;
  const int OPEN = 1;
  const int CLOSING = 2;
  const int CLOSED = 3;

  Manager _manager;
  Object _id;

  Socket _socket;

  bool _open;
  bool _disconnected;
  bool _drained;
  bool _discarded;
  bool _handlersSet;

  Timer _heartbeatTimeout;
  Timer _heartbeatInterval;
  Timer _closeTimeout;

  Transport(this._manager, data, request) :
    _disconnected = false, _drained = true {
    _id = data.id;
    handleRequest(request);
  }

  /**
   * Access the logger.
   */
  Logger get log => _manager.log;

  /**
   * Access the store.
   */
  Store get store => _manager.store;

  /**
   * Handles a request when it's set.
   */
  handleRequest(HttpRequest req) {
    log.fine('setting request ${req.method}, ${req.uri}');
    this.req = req;

    if (req.method == 'GET') {
      _socket = req.socket;
      _open = true;
      _drained = true;
      setHeartbeatInterval();

      setHandlers();
      onSocketConnect();
    }
  }

  /**
   * Called when a connection is first set.
   */
  onSocketConnect() { }

  /**
   * Sets transport handlers
   */
  setHandlers() {
    // we need to do this in a pub/sub way since the client can POST the message
    // over a different socket (ie: different Transport instance)
    store.subscribe('heartbeat-clear:$_id', () {
      onHeartbeatClear();
    });

    store.subscribe('disconnect-force:$_id', () {
      onForcedDisconnect();
    });

    store.subscribe('dispatch:$_id', (packet, volatile) {
      onDispatch(packet, volatile);
    });

    _socket.on('end', onSocketEnd);
    _socket.on('close', onSocketClose);
    _socket.on('error', onSocketError);
    _socket.on('drain', onSocketDrain);

    _handlersSet = true;
  }

  /**
   * Removes transport handlers
   */
  clearHandlers() {
    if (_handlersSet) {
      store.unsubscribe('disconnect-force:$_id');
      store.unsubscribe('heartbeat-clear:$_id');
      store.unsubscribe('dispatch:$_id');

      _socket.removeListener('end', onSocketEnd);
      _socket.removeListener('close', onSocketClose);
      _socket.removeListener('error', onSocketError);
      _socket.removeListener('drain', onSocketDrain);
    }
  }

  /**
   * Called when the connection dies
   */
  onSocketEnd() {
    end('socket end');
  }

  /**
   * Called when the connection dies
   */
  onSocketClose(error) {
    end(error ? 'socket error' : 'socket close');
  }

  /**
   * Called when the connection has an error.
   */
  onSocketError(err) {
    if (_open) {
      _socket.destroy();
      onClose();
    }

    log.info('socket error ${err.stack}');
  }

  /**
   * Called when the connection is drained.
   */
  onSocketDrain() {
    _drained = true;
  }

  /**
   * Called upon receiving a heartbeat packet.
   */
  onHeartbeatClear() {
    clearHeartbeatTimeout();
    setHeartbeatInterval();
  }

  /**
   * Called upon a forced disconnection.
   */
  onForcedDisconnect() {
    if (!_disconnected) {
      log.info('transport end by forced client disconnection');
      if (_open) {
        this.packet({ 'type': 'disconnect' });
      }
      end('booted');
    }
  }

  /**
   * Dispatches a packet.
   */
  onDispatch(packet, bool volatile) {
    if (volatile) {
      writeVolatile(packet);
    } else {
      write(packet);
    }
  }

  /**
   * Sets the close timeout.
   */
  setCloseTimeout() {
    if (_closeTimeout == null) {
      _closeTimeout = new Timer(_manager.get('close timeout') * 1000, (_) {
        log.fine('fired close timeout for client $_id');
        _closeTimeout = null;
        end('close timeout');
      });

      log.fine('set close timeout for client $_id');
    }
  }

  /**
   * Clears the close timeout.
   */
  clearCloseTimeout() {
    if (_closeTimeout != null) {
      _closeTimeout.cancel();
      _closeTimeout = null;

      log.fine('cleared close timeout for client $_id');
    }
  }

  /**
   * Sets the heartbeat timeout.
   */
  setHeartbeatTimeout() {
    if (_heartbeatTimeout == null && _manager.enabled('heartbeats')) {
      _heartbeatTimeout = new Timer(_manager.get('heartbeat timeout') * 1000, (_) {
        log.fine('fired heartbeat timeout for client $_id');
        _heartbeatTimeout = null;
        end('heartbeat timeout');
      });

      log.fine('set heartbeat timeout for client $_id');
    }
  }

  /**
   * Clears the heartbeat timeout
   */
  clearHeartbeatTimeout() {
    if (_heartbeatTimeout != null && _manager.enabled('heartbeats')) {
      _heartbeatTimeout.cancel();
      _heartbeatTimeout = null;
      log.fine('cleared heartbeat timeout for client $_id');
    }
  }

  /**
   * Sets the heartbeat interval. To be called when a connection opens and when
   * a heartbeat is received.
   */
  setHeartbeatInterval() {
    if (_heartbeatInterval == null && _manager.enabled('heartbeats')) {
      _heartbeatInterval = new Timer(_manager.get('heartbeat interval') * 1000, (_) {
        heartbeat();
        _heartbeatInterval = null;
      });

      log.fine('set heartbeat interval for client $_id');
    }
  }

  /**
   * Clears the heartbeat interval.
   */
  clearHeartbeatInterval() {
    if (_heartbeatInterval != null && _manager.enabled('heartbeats')) {
      _heartbeatInterval.cancel();
      _heartbeatInterval = null;
      log.fine('cleared heartbeat interval for client $_id');
    }
  }

  /**
   * Clears all timeouts.
   */
  clearTimeouts() {
    clearCloseTimeout();
    clearHeartbeatTimeout();
    clearHeartbeatInterval();
  }

  /**
   * Sends a heartbeat
   */
  heartbeat() {
    if (_open) {
      log.fine('emitting heartbeat for client $_id');
      packet({ 'type': 'heartbeat' });
      setHeartbeatTimeout();
    }
  }

  /**
   * Handles a message [packet].
   */
  onMessage(packet) {
    var current = _manager.transports[_id];

    if ('heartbeat' == packet.type) {
      log.fine('got heartbeat packet');

      if (current != null && current.open) {
        current.onHeartbeatClear();
      } else {
        store.publish('heartbeat-clear: $_id');
      }
    } else {
      if ('disconnect' == packet.type && packet.endpoint == '') {
        log.fine('got disconnection packet');

        if (current != null) {
          current.onForcedDisconnect();
        } else {
          store.publish('disconnect-force: $_id');
        }

        return;
      }

      if (packet.id && packet.ack != 'data') {
        log.fine('acknowledging packet automatically');

        var ack = Parser.encodePacket({
          'type': 'ack',
          'ackId': packet.id,
          'endpoint': packet.endpoint || ''
        });

        if (current != null && current.open) {
          current.onDispatch(ack);
        } else {
          _manager.onClientDispatch(_id, ack);
          store.publish('dispatch:$_id', ack);
        }
      }

      // handle packet locally or publish it
      if (current != null) {
        _manager.onClientMessage(_id, packet);
      } else {
        store.publish('message:$_id', packet);
      }
    }
  }

  /**
   * Finishes the connection and makes sure client doesn't reopen.
   */
  disconnect(String reason) {
    packet({ 'type': 'disconnect' });
    end(reason);
  }

  /**
   * Closes the connection.
   */
  close() {
    if (_open) {
      doClose();
      onClose();
    }
  }

  /**
   * Closes the connection.
   */
  doClose();

  /**
   * Called upon a connection close.
   */
  onClose() {
    if (_open) {
      setCloseTimeout();
      clearHandlers();
      _open = false;
      _manager.onClose(_id);
      store.publish('close', _id);
    }
  }

  /**
   * Cleans up the connection, considers the client disconnected.
   */
  end(String reason) {
    if (!_disconnected) {
      log.info('transport end ($reason)');

      var local = _manager.transports[_id];

      close();
      clearTimeouts();
      _disconnected = true;

      if (local != null) {
        _manager.onClientDisconnect(_id, reason, true);
      } else {
        store.publish('disconnect:$_id', reason);
      }

      store.publish('kick', _id);
    }
  }

  /**
   * Signals that the transport should pause and buffer data.
   */
  discard() {
    log.fine('discarding transport');
    _discarded = true;
    clearTimeouts();
    clearHandlers();
  }

  /**
   * Writes an error packet with the specified [reason] and [advice].
   */
  error(String reason, [String advice]) {
    packet({
      'type': 'error',
      'reason': reason,
      'advice': advice
    });

    log.warning('$reason ${?advice ? 'client should $advice' : ''}');
    end('error');
  }

  /**
   * Write a packet.
   */
  packet(obj) {
    return write(Parser.encodePacket(obj));
  }

  /**
   * Writes [data] to the socket.
   */
  write(data);

  /**
   * Writes a volatile message.
   */
  writeVolatile(data) {
    if (_open) {
      if (_drained) {
        write(data);
      } else {
        log.fine('ignoring volatile packet, buffer not drained');
      }
    } else {
      log.fine('ignoring volatile packet, transport not open');
    }
  }
}
