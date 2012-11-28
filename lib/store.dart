library store;

abstract class Client {
  Store store;
  String id;

  /**
   * Destroy the client.
   * @param expiration number of seconds to expire data
   */
  Client destroy(int expiration);
}

abstract class Store {

  Client client(String id);
  publish();
  subscribe();
  unsubscribe();

}

class AbstractStore implements Store {
  Map<String, Client> _clients;

  Store(Map options) {
    _clients = new Map<String, Client>();
  }

  /**
   * Initializes a client store.
   */
  Client client(String id) {
    if (!_clients.containsKey(id)) {
      _clients[id] = new Client(this, id);
    }
    return _clients[id];
  }

  /**
   * Destroys a client.
   */
  Store _destroyClient(String id, int expiration) {
    if (_clients.containsKey(id)) {
      _clients[id].destroy(expiration);
    }
    return this;
  }

  /**
   * Destroys the store.
   */
  Store _destroy([int expiration]) {
    _clients.values.forEach((c) => _destroyClient(c, expiration));
    _clients = new Map<String, Client>();
    return this;
  }
}
