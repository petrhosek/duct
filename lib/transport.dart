library transport;

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

abstract class Transport {
  void handleRequest(req);

  void setHandlers();
  void clearHandlers();

  void onSocketConnect();
  void onSocketEnd();
  void onSocketClose();
  void onSocketError();
  void onSocketDrain();

  void onHearbeatClear();
  void onForcedDisconnect();

  void onDispatch(Packet packet, bool volatile);
  void onMessage(Packet packet);
  void onClose();

  void setCloseTimeout();
  void clearCloseTimeout();

  void setHeartbeatTimeout();
  void clearHeartbeatTimeout();

  void setHearbeatInterval();
  void clearHeartbeatInterval();

  void clearTimeouts();

  void heartbeat();
  void disconnect(reason);
  void close();
  void end(reason);
  void discard();
  void error(reason, advice);
  void packet(Object object);

  void writeVolatile(String msg);
}

class _Transport {

}
