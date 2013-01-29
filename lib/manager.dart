library manager;

import 'dart:io';
import 'package:logging/logging.dart';

import 'namespace.dart';
import 'transport.dart';

class Manager {
  Map rooms;
  bool static;
  HttpServer server;

  Map<String, Transport> transports;
  
  Map _namespaces;
  Map _sockets;
  
  Map _rooms;
  Map _roomClients;
  
  Logger _logger = new Logger('Manager');

  Map _client;
  Map _handshaken;
  
  Map<String, Object> _settings;

  Map get client => _client;
  Map get handshaken => _handshaken;

  Manager(this.server, options) {
    _namespaces = new Map();
    _sockets = new Map();
    transports = new Map();

    _rooms = new Map<String, List<String>>();
    _roomClients = new Map<String, Map<String, bool>>();

    options.forEach((k, v) => _settings[k] = v);
    
    server.on('request', (req, res) {
      handleRequest(req, res);
    });

    server.on('upgrade', (req, socket, head) {
      handleUpgrade(req, socket, head);
    });
    
    server.addRequestHandler(
        (req) => req.headers[HttpHeaders.UPGRADE] != null,
        _handleUpgrade);

    server.on('close', () {
      //clearInterval(gc);
    });

    server.once('listening', () {
      //gc = setInterval(_garbageCollection, 1000);
    });

    transports.forEach((Transport t) {
      if (t.init != null) {
        t.init(this);
      }
    });
  }

  get store => get('store');

  get(String key) => _settings[key];
  set(String key, [Object value = null]) {
    if (value == null) {
      return _settings[key];
    }

    _settings[key] = value;
    emit('set:$key', _settings[key], key);
  }

  void enable(String key) {
    _settings[key] = true;
    emit('set:$key', _settings[key], key);
  }

  void disable(String key) {
    _settings[key] = false;
    emit('set:$key', _settings[key], key);
  }

  bool enabled(String key) => _settings[key] != false;
  bool disabled(String key) => _settings[key] == false;

  Manager configure(Object env, void callback(Manager manager)) {
    if (env is Function) {
      env(this);
    } else if (env == 'development') {
      callback(this);
    }

    return this;
  }

  void _initStore() {
  }

  /**
   * Called when a client handshakes.
   */
  void onHandshake(String id, String data) {
    _handshaken[id] = data;
  }

  /**
   * Called when a client connects (i.e. transport first opens)
   */
  void onConnect(String id) {
    _connected[id] = true;
  }

  /**
   * Called when a client opens a request in a different node.
   */
  void onOpen(String id) {
    _open[id] = true;

    if (_closed.containsKey(id)) {
      store.unsubscribe('dispatch:$id').then(() {
        Transport transport = transports[id];
        if (_closed.containsKey(id) && transport != null) {
          if (transport.open) {
            transport.payload(_closed[id]);
            _closed.remove(id);
          }
        }
      });
    }

    if (transports.containsKey(id)) {
      transports[id].discard();
      transports.remove(id);
    }
  }

  /**
   * Called when a message is sent to a namespace and/or room.
   */
  void onDispatch(String room, Packet packet, bool volatile, List exceptions) {
    if (this.rooms[room]) {
      for (var i = 0, l = this.rooms[room].length; i < l; i++) {
        var id = this.rooms[room][i];

        if (!~exceptions.indexOf(id)) {
          if (this.transports[id] && this.transports[id].open) {
            this.transports[id].onDispatch(packet, volatile);
          } else if (!volatile) {
            this.onClientDispatch(id, packet);
          }
        }
      }
    }
  }

  /**
   * Called when a client joins a namespace/room.
   */
  void onJoin(String id, String name) {
    _roomClients.putIfAbsent(id, () => <String, bool>{});
    _rooms.putIfAbsent(name, () => <String>[]);

    if (_rooms[name].indexOf(id) == -1) {
      _rooms[name].add(id);
      _roomClients[id][name] = true;
    }
  }

  /**
   * Called when a client leave a namespace/room.
   */
  void onLeave(String id, String room) {
    if (_rooms.containsKey(room)) {
      int index = _rooms[room].indexOf(id);

      if (index >= 0) {
        _rooms[rooms].removeRange(index, 1);
      }

      if (_rooms[room].length == 0) {
        _rooms.remove(room);
      }
      _roomClients[id].delete(room);
    }
  }

  /**
   * Called when a client closes a request in different node.
   */
  void onClose(String id) {
    if (_open[id]) {
      _open.delete(id);
    }

    _closed[id] = <Packet>[];

    _store.subscribe('dispatch:$id', (Packet packet, bool volatile) {
      if (!volatile) {
        onClientDispatch(id, packet);
      }
    });
  }

  /**
   * Dispatches a message for a closed client.
   */
  void onClientDispatch(String id, Packet packet) {
    if (_closed[id]) {
      _closed[id].addLast(packet);
    }
  }

  /**
   * Receives a message for a client.
   */
  void onClientMessage(String id, Packet packet) {
    if (_namespaces.containsKey[packet.endpoint]) {
      _namespaces[packet.endpoint].handlePacket(id, packet);
    }
  }

  /**
   * Fired when a client disconnects (not triggered).
   */
  void onClientDisconnect(String id, String reason) {
    _namespaces.forEach((name, value) {
      if (_roomClients.containsKey(id) && _roomClients[id].containsKey(name)) {
        value.handleDisconnect(id, reason);
      }
    });
    onDisconnect(id);
  }

  /**
   * Called when a client disconnects.
   */
  void onDisconnect(String id, [bool local=false]) {
    delete this.handshaken[id];

    if (this.open[id]) {
      delete this.open[id];
    }

    if (this.connected[id]) {
      delete this.connected[id];
    }

    if (this.transports[id]) {
      this.transports[id].discard();
      delete this.transports[id];
    }

    if (this.closed[id]) {
      delete this.closed[id];
    }

    if (this.roomClients[id]) {
      for (var room in this.roomClients[id]) {
        if (this.roomClients[id].hasOwnProperty(room)) {
          this.onLeave(id, room);
        }
      }
      delete this.roomClients[id]
    }

    this.store.destroyClient(id, this.get('client store expiration'));

    this.store.unsubscribe('dispatch:' + id);

    if (local) {
      this.store.unsubscribe('message:' + id);
      this.store.unsubscribe('disconnect:' + id);
    }
  }

  /**
   * Handles an HTTP request.
   */
  void _handleRequest(req, res) {
    var data = this.checkRequest(req);

    if (!data) {
      for (var i = 0, l = this.oldListeners.length; i < l; i++) {
        this.oldListeners[i].call(this.server, req, res);
      }

      return;
    }

    if (data.static || !data.transport && !data.protocol) {
      if (data.static && this.enabled('browser client')) {
        this.static.write(data.path, req, res);
      } else {
        res.writeHead(200);
        res.end('Welcome to socket.io.');

        this.log.info('unhandled socket.io url');
      }

      return;
    }

    if (data.protocol != protocol) {
      res.writeHead(500);
      res.end('Protocol version not supported.');

      this.log.info('client protocol version unsupported');
    } else {
      if (data.id) {
        this.handleHTTPRequest(data, req, res);
      } else {
        this.handleHandshake(data, req, res);
      }
    }
  }

  /**
   * Handles an HTTP Upgrade.
   */
  void _handleUpgrade(req, socket, head) {
    var data = this.checkRequest(req)
        , self = this;

    if (!data) {
      if (this.enabled('destroy upgrade')) {
        socket.end();
        this.log.debug('destroying non-socket.io upgrade');
      }

      return;
    }

    var self = this;
    this.ws.handleUpgrade(req, socket, head, (client) {
      req.wsclient = client;
      self.handleClient(data, req);
    });
  }

  /**
   * Handles a normal handshaken HTTP request (eg: long-polling).
   */
  void _handleHTTPRequest(data, req, res) {
    req.res = res;
    this.handleClient(data, req);
  }
  
  /**
   * Intantiantes a new client.
   */
  void _handleClient(data, req) {
    var socket = req.socket
        , store = this.store
        , self = this;

    // handle sync disconnect xhrs
    if (undefined != data.query.disconnect) {
      if (this.transports[data.id] && this.transports[data.id].open) {
        this.transports[data.id].onForcedDisconnect();
      } else {
        this.store.publish('disconnect-force:' + data.id);
      }
      req.res.writeHead(200);
      req.res.end();
      return;
    }

    if (!~this.get('transports').indexOf(data.transport)) {
      this.log.warn('unknown transport: "' + data.transport + '"');
      req.connection.end();
      return;
    }

    var transport = new transports[data.transport](this, data, req)
        , handshaken = this.handshaken[data.id];

    if (transport.disconnected) {
      // failed during transport setup
      req.connection.end();
      return;
    }
    if (handshaken) {
      if (transport.open) {
        if (this.closed[data.id] && this.closed[data.id].length) {
          transport.payload(this.closed[data.id]);
          this.closed[data.id] = [];
        }

        this.onOpen(data.id);
        this.store.publish('open', data.id);
        this.transports[data.id] = transport;
      }

      if (!this.connected[data.id]) {
        this.onConnect(data.id);
        this.store.publish('connect', data.id);

        // flag as used
        delete handshaken.issued;
        this.onHandshake(data.id, handshaken);
        this.store.publish('handshake', data.id, handshaken);

        // initialize the socket for all namespaces
        for (var i in this.namespaces) {
          if (this.namespaces.hasOwnProperty(i)) {
            var socket = this.namespaces[i].socket(data.id, true);

            // echo back connect packet and fire connection event
            if (i === '') {
              this.namespaces[i].handlePacket(data.id, { type: 'connect' });
            }
          }
        }

        this.store.subscribe('message:' + data.id, (packet) {
          self.onClientMessage(data.id, packet);
        });

        this.store.subscribe('disconnect:' + data.id, (reason) {
          self.onClientDisconnect(data.id, reason);
        });
      }
    } else {
      if (transport.open) {
        transport.error('client not handshaken', 'reconnect');
      }

      transport.discard();
    }
  }

  /**
   * Handles a handshake request.
   */
  void _handleHanshake(Object data, req, res) {
    var self = this
        , origin = req.headers.origin
        , headers = {
                     'Content-Type': 'text/plain'
    };
  
    function writeErr (status, message) {
      if (data.query.jsonp && jsonpolling_re.test(data.query.jsonp)) {
        res.writeHead(200, { 'Content-Type': 'application/javascript' });
        res.end('io.j[' + data.query.jsonp + '](new Error("' + message + '"));');
      } else {
        res.writeHead(status, headers);
        res.end(message);
      }
    };
  
    function error (err) {
      writeErr(500, 'handshake error');
      self.log.warn('handshake error ' + err);
    };
  
    if (!this.verifyOrigin(req)) {
      writeErr(403, 'handshake bad origin');
      return;
    }
  
    var handshakeData = this.handshakeData(data);
  
    if (origin) {
      // https://developer.mozilla.org/En/HTTP_Access_Control
      headers['Access-Control-Allow-Origin'] = origin;
      headers['Access-Control-Allow-Credentials'] = 'true';
    }
  
    this.authorize(handshakeData, function (err, authorized, newData) {
      if (err) return error(err);
  
      if (authorized) {
        var id = base64id.generateId()
          , hs = [
                id
              , self.enabled('heartbeats') ? self.get('heartbeat timeout') || '' : ''
              , self.get('close timeout') || ''
              , self.transports(data).join(',')
            ].join(':');
  
        if (data.query.jsonp && jsonpolling_re.test(data.query.jsonp)) {
          hs = 'io.j[' + data.query.jsonp + '](' + JSON.stringify(hs) + ');';
          res.writeHead(200, { 'Content-Type': 'application/javascript' });
        } else {
          res.writeHead(200, headers);
        }
  
        res.end(hs);
  
        self.onHandshake(id, newData || handshakeData);
        self.store.publish('handshake', id, newData || handshakeData);
  
        self.log.info('handshake authorized', id);
      } else {
        writeErr(403, 'handshake unauthorized');
        self.log.info('handshake unauthorized');
      }
    });
  }

  /**
   * Gets normalized handshake data.
   */
  void _handshakeData(String data) {
    var connection = data.request.connection
        , connectionAddress
        , date = new Date;

    if (connection.remoteAddress) {
      connectionAddress = {
                           address: connection.remoteAddress
                           , port: connection.remotePort
      };
    } else if (connection.socket && connection.socket.remoteAddress) {
      connectionAddress = {
                           address: connection.socket.remoteAddress
                           , port: connection.socket.remotePort
      };
    }

    return {
        headers: data.headers
      , address: connectionAddress
      , time: date.toString()
      , query: data.query
      , url: data.request.url
      , xdomain: !!data.request.headers.origin
      , secure: data.request.connection.secure
      , issued: +date
    };
  }

  /**
   * Verifies the origin of a request.
   */
  bool _verifyOrigin(req) {
    var origin = request.headers.origin || request.headers.referer
        , origins = this.get('origins');

    if (origin == 'null') origin = '*';

    if (origins.indexOf('*:*') != -1) {
      return true;
    }

    if (origin) {
      try {
        var parts = url.parse(origin);
        parts.port = parts.port || 80;
        var ok =
            ~origins.indexOf(parts.hostname + ':' + parts.port) ||
            ~origins.indexOf(parts.hostname + ':*') ||
            ~origins.indexOf('*:' + parts.port);
        if (!ok) this.log.warn('illegal origin: ' + origin);
        return ok;
      } catch (ex) {
        this.log.warn('error parsing origin');
      }
    }
    else {
      this.log.warn('origin missing from handshake, yet required by config');
    }
    return false;
  }

  /**
   * Handles an incoming packet.
   */
  void handlePacket(String sessid, Packet packet) {
    this.of(packet.endpoint || '').handlePacket(sessid, packet);
  }

  /**
   * Performs authentication.
   *
   * @param Object client request data
   */
  void _authorize(Object data, Function fn) {
    if (this.get('authorization')) {
      var self = this;

      this.get('authorization').call(this, data, function (err, authorized) {
        self.log.debug('client ' + (authorized ? 'authorized' : 'unauthorized'));
        fn(err, authorized);
      });
    } else {
      this.log.debug('client authorized');
      fn(null, true);
    }
  }

  /**
   * Retrieves the transports adviced to the user.
   */
  List _transports(Object data) {
    var transp = this.get('transports')
        , ret = [];

    for (var i = 0, l = transp.length; i < l; i++) {
      var transport = transp[i];

      if (transport) {
        if (!transport.checkClient || transport.checkClient(data)) {
          ret.push(transport);
        }
      }
    }

    return ret;
  }
  
  var regexp = '/^\/([^\/]+)\/?([^\/]+)?\/?([^\/]+)?\/?$/';

  /**
   * Checks whether a request is a socket.io one.
   *
   * @return {Object} a client request data object or `false`
   */
  bool checkRequest(req) {
    var resource = this.get('resource');

    var match;
    if (typeof resource === 'string') {
      match = req.url.substr(0, resource.length);
      if (match !== resource) match = null;
    } else {
      match = resource.exec(req.url);
      if (match) match = match[0];
    }

    if (match) {
      var uri = url.parse(req.url.substr(match.length), true)
          , path = uri.pathname || ''
          , pieces = path.match(regexp);

      // client request data
      var data = {
                  query: uri.query || {}
        , headers: req.headers
        , request: req
        , path: path
      };
  
      if (pieces) {
        data.protocol = Number(pieces[1]);
        data.transport = pieces[2];
        data.id = pieces[3];
        data.static = !!this.static.has(path);
      };
  
      return data;
    }
  
    return false;
  }

  /**
   * Declares a socket namespace.
   */
  SocketNamespace of(String namespace) {
    if (this.namespaces[namespace]) {
      return this.namespaces[namespace];
    }

    return this.namespaces[namespace] = new SocketNamespace(this, namespace);
  }

  /**
   * Perform garbage collection on long living objects and properties that cannot
   * be removed automatically.
   */
  void _garbageCollection() {
    // clean up unused handshakes
    var ids = Object.keys(this.handshaken)
        , i = ids.length
        , now = Date.now()
        , handshake;

    while (i--) {
      handshake = this.handshaken[ids[i]];

      if ('issued' in handshake && (now - handshake.issued) >= 3E4) {
        this.onDisconnect(ids[i]);
      }
    }
  }
}
