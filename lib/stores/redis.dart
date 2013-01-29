library redis_store;

import '../store.dart';
import 'package:dartredisclient/redis_client.dart';

class _RedisClient implements Client {
  RedisStore store;
  String id;
  
  _RedisClient(this.store, this.id);

  /**
   * Gets a key [key].
   */
  Future<Object> get(String key) => store._client.hget(id, key);

  /**
   * Sets a key [key] with value [value].
   */
  Future<bool> set(String key, Object value) => store._client.hset(id, key, value);

  /**
   * Deletes a key [key].
   */
  Future<int> del(String key) => store._client.hdel(id, key);

  /**
   * Has a key [key]?
   */
  Future<bool> has(String key) => store._client.hexists(id, key);

  /**
   * Destroys client.
   */
  void destroy([int expiration]) {
    if (?expiration) {
      store._client.expire(id, expiration);
    } else {
      store._client.del(id);
    }
  }
}

class RedisStore extends Store {
  RedisClient _client;

  RedisStore([options = const {}]): super(options) {
    if (options['client'] is RedisClient) {
      _client = options['client'];
    } else {
      _client = new RedisClient(options['connStr']);
    }
  }
  
  Client createClient(Store store, String id) => new _RedisClient(store, id);
  
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

  /**
   * Destroys the store.
   */
  void destroy([int expiration]) {
    super.destroy();
    _client.quit();
  }

}
