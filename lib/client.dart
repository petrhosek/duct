library client;

import 'parser.dart';

import 'package:logging/logging.dart';

class Client {
  
  Server _server;
  Connection _conn;
  
  Logger _logger = new Logger('Client');
  
  /**
   * Client constructor.
   *
   * @param {Server} server instance
   * @param {Socket} connection
   */
  Client(this._server, this._conn){
    this.id = conn.id;
    this.request = conn.request;
    this.setup();
    this.sockets = [];
    this.nsps = {};
  }
  
  /**
   * Sets up event listeners.
   */
  setup() {
    this.onclose = this.onclose.bind(this);
    this.ondata = this.ondata.bind(this);
    this.conn.on('data', this.ondata);
    this.conn.on('close', this.onclose);
  }
  
  /**
   * Connects a client to a namespace.
   *
   * @param {String} namespace name
   */
  connect(name) {
    _logger.fine('connecting to namespace $name');
    var nsp = this.server.of(name);
    var socket = nsp.add(this, () {
      _sockets.push(socket);
      _nsps[nsp.name] = socket;
    });
  }
  
  /**
   * Disconnects from all namespaces and closes transport.
   */
  disconnect() {
    var socket;
    // we don't use a for loop because the length of
    // `sockets` changes upon each iteration
    while (socket = this.sockets.shift()) {
      socket.disconnect();
    }
    this.close();
  }
  
  /**
   * Removes a socket. Called by each `Socket`.
   */
  remove(socket) {
    var i = this.sockets.indexOf(socket);
    if (~i) {
      var nsp = this.sockets[i].nsp.name;
      this.sockets.splice(i, 1);
      _nsps.remove(nsp);
    } else {
      _logger.fine('ignoring remove for ${socket.id}');
    }
  }
  
  /**
   * Closes the underlying connection.
   */
  close() {
    if ('open' == this.conn.readyState) {
      _logger.fine('forcing transport close');
      this.conn.close();
      this.onclose('forced server close');
    }
  }
  
  /**
   * Writes a packet to the transport.
   *
   * @param {Object} packet object
   */
  packet(packet) {
    if ('open' == this.conn.readyState) {
      _logger.fine('writing packet $packet');
      this.conn.write(Parser.encode(packet));
    } else {
      _logger.fine('ignoring packet write $packet');
    }
  }
  
  /**
   * Called with incoming transport data.
   */
  ondata(data) {
    var packet = Parser.decode(data.toString());
    _logger.fine('got packet $packet');
  
    if (Parser.CONNECT == packet.type) {
      this.connect(packet.nsp);
    } else {
      var socket = this.nsps[packet.nsp];
      if (socket) {
        socket.onpacket(packet);
      } else {
        _logger.fine('no socket for namespace ${packet.nsp}');
      }
    }
  }
  
  /**
   * Called upon transport close.
   *
   * @param {String} reason
   */
  onclose(reason) {
    _logger.fine('client close with reason $reason');
  
    // ignore a potential subsequent `close` event
    this.destroy();
  
    // `nsps` and `sockets` are cleaned up seamlessly
    this.sockets.forEach((socket) {
      socket.onclose(reason);
    });
  }
  
  /**
   * Cleans up event listeners.
   */
  destroy() {
    this.conn.removeListener('data', this.ondata);
    this.conn.removeListener('close', this.onclose);
  }
  
}