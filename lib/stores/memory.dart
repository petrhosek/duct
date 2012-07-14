#library('memory');

#import('../store.dart');

class MemoryClient implements Client {

  Store store;
  String id;
  Map _data;

  MemoryClient(this.store, this.id);

  get(String key, fn);
  set(String key, String value, fn);
  has(String key, fn);
  del(String key, fn);

  Client destroy(int expiration) {
    setTimeout(() => _data = new Map(), expiration * 1000);
    return this;
  }

  static Map<String, Client> _clients;

  factory MemoryClient(String id) {
    if (_clients == null) {
      _clients = {};
    }

    if (_clients.containsKey(id)) {
      return _clients[id];
    } else {
      final client = new MemoryClient._internal(this, id);
      _clients[id] = client;
      return client;
    }
  }

  MemoryClient._internal(this.id);

}

class MemoryStore extends AbstractStore {

  Memory(Map options): super(options) {
  }

}
