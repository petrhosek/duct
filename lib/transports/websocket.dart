library websocket;

import '../manager.dart';
import '../parser.dart';
import '../transport.dart';

import 'dart:io';

/**
 * HTTP interface constructor. Interface compatible with all transports that
 * depend on request-response cycles.
 */
class WebSocketTransport extends Transport {
  WebSocket _socket;
  
  WebSocketTransport(Manager manager, data, req) :
    super(manager, data, req) {
    _socket = req.wsclient;
  
    _socket.onclose = (event) {
      this.end('socket end');
    };
    _socket.onerror = (e) {
      this.end('socket error');
    };
    _socket.onmessage = (event) {
      this.onMessage(Parser.decodePacket(event.data));
    };
  }
  
  /**
   * Writes [data] to the socket.
   */
  write(data) => _socket.send(data);
  
  /**
   * Closes the connection.
   */
  doClose() => _socket.close();
}