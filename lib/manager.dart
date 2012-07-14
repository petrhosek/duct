#library('manager');

#import('dart:io');

interface Manager default _Manager {
}

class _Manager {

  Map rooms;
  bool static;
  HttpServer server;
  Map transports;

  Map _client;
  Map _handshaken;

  Map get client() => _client;
  Map get handshaken() => _handshaken;

  _Manager(this.server, options) {
    _namespaces = new Map<>();
    _sockets = new Map<>();
    transports = new Map<>();

    _rooms = new Map<String, List<String>>();
    _roomClients = new Map<String, Map<String, bool>>();

    options.forEach((k, v) => _settings[k] = v);

    server.on('request', (req, res) {
      handleRequest(req, res);
    });

    server.on('upgrade', (req, socket, head) {
      handleUpgrade(req, socket, head);
    });

    server.on('close', () {
      //clearInterval(gc);
    });

    server.once('listening', () {
      //gc = setInterval(_garbageCollection, 1000);
    });

    transports.forEach((t) {
      if (t.init != null)
        t.init(this);
    });
  }

  get store() => get('store');

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

  void onOpen(String id) {
    _open[id] = true;

    if (_closed.containsKey(id)) {
      store.unsubscribe('dispatch:$id').then(() {
        Transport transport = _transports[id];
        if (_closed.containsKey(id) && transport != null) {
          if (transport.open) {
            transport.payload(_closed[id]);
            _closed.remove(id);
          }
        }
      });
    }

    if (_transports.containsKey(id)) {
      _transports[id].discard();
      _transports.remove(id);
    }
  }

  void onDispatch(String room, Packet packet, bool volatile, List exceptions) {
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
        _rooms.delete(room);
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
    })
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
    })
    onDisconnect(id);
  }

  /**
   * Called when a client disconnects.
   */
  void onDisconnect(String id, [bool local=false]) {
    
  }

  void handleRequest(req, res) {
  }

  void handleUpgrade(req, socket, head) {
  }

  void handleClient(data, req) {
  }

  void handleHanshake(Object data, req, res) {
  }

  void handshakeData(String data) {
  }

  bool verifyOrigin(req) {
  }

  void handlePacket(String sessid, Packet packet) {
  }

  void authorize(Object data, Function fn) {
  }

  List transports(Object data) {
  }

  bool checkRequest(req) {
  }

  SocketNamespace of(String namespace) {
  }

  void garbageCollection() {
  }

  String _generateId() {
  }
}
