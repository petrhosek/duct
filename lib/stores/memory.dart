library memory_store;

import '../store.dart';
import 'dart:isolate';

class _MemoryClient implements Client {
  MemoryStore store;
  String id;
  Map<String, Object> _data;

  _MemoryClient(this.store, this.id) {
    _data = new Map<String, Object>();
  }

  /**
   * Gets a key [key].
   */
  Future<Object> get(String key) => new Future.immediate(_data[key]);

  /**
   * Sets a key [key] with value [value].
   */
  Future<bool> set(String key, Object value) {
    _data[key] = value;
    return new Future.immediate(true);
  }

  /**
   * Deletes a key [key].
   */
  Future<int> del(String key) {
    _data.remove(key);
    return new Future.immediate(1);
  }

  /**
   * Has a key [key]?
   */
  Future<bool> has(String key) => new Future.immediate(_data.containsKey(key));

  /**
   * Destroys client.
   */
  void destroy([int expiration]) {
    if (expiration != null) {
      new Timer(expiration * 1000, (_) => _data = <String, Object>{});
    } else {
      _data = new Map<String, Object>();
    }
  }
}

class MemoryStore extends Store {

  MemoryStore([options = const {}]): super(options);
  
  Client createClient(Store store, String id) => new _MemoryClient(store, id);

  /**
   * Publishes a message.
   */
  publish(String name, [data]) {}

  /**
   * Subscribes to a channel.
   */
  subscribe(String name, Function fn) {}

  /**
   * Unsubscribes from a channel.
   */
  unsubscribe(String name) {}
  
}
