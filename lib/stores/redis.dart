library redis;

import '../store.dart';
import 'package:redis/RedisClient.dart';

class RedisClient implements Client {

  String id;
  RedisStore _store;

  Future<Object> get(String key) => _store.cmd.hget(_id, key);
  Future<bool> set(String key, Object value) => _store.cmd.hset(_id, key, value);
  Future<int> del(String key) => _store.cmd.hdel(_id, key, value);
  Future<bool> has(String key) => _store.cmd.hexists(_id, key);

  /**
   * Destroys client.
   */
  void destroy([int expiration]) {
    if (expiration == null) {
      _store.client.del(_id);
    } else {
      _store.client.expire(_id, expiration);
    }
  }

  RedisClient._internal(this.id);

}

class RedisStore extends AbstractStore {

  RedisClient pub, sub, cmd;

  RedisStore([Map options={}]): super(options) {
    RedisClient client = new RedisClient('');
  }

  /**
   * Publishes a message.
   */
  void publish(String name) {
  }

  void subscribe(String name, String consumer, [Function callback]) {
    sub.subscribe(name);

    if (consumer != null) {
      void subscribe(channel) {
        if (name == channel) {
          void message(String channel, msg) {
            if (name == channel) {
              msg = unpack(msg);

              // check that the message wasn't emitted by this node
              if (_nodeId != msg.nodeId) {
                consumer();
              }
            }
          };
          sub.on.message.add(message);

          void unsubscribe(String channel) {
            if (name == channel) {
              sub.messageListeners.remove(message);
              unsubscribeListeners.remove(unsubscribe);
            }
          };
          on.unsubscribe.add(unsubscribe);

          sub.subcribeListeners.remove(subscribe);

          if (callback != null) {
            callback();
          } // TODO: use futures
        }
      };
      sub.on.subscribe.add(subscribe);
    }
  }

  void unsubscribe(String name, Function callback) {
  }

  /**
   * Destroys the store.
   */
  void destroy() {
    super.destroy();
    pub.end();
    sub.end();
    cmd.end();
  }

}
