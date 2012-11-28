library transport;

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
