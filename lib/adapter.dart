library adapter;

class Adapter {
  Map _nsp;
  Map _rooms;
  Map _sid;
  
  /**
   * Memory adapter constructor.
  *
   * @param nsp namespace
   */
  Adapter(this._nsp);
  
  /**
   * Adds a socket from a room.
   *
   * @param id socket id
   * @param room room name
   * @param fn callback
   */
  add(String id,  String room, [Function fn]) {
    _sids.putIfAbsent(id, () -> {})[room] = true;
    _rooms.putIfAbsent(room, () -> {})[id] = true;
    if (?fn) process.nextTick(fn.bind(null, null));
  }

  /**
   * Removes a socket from a room.
   *
   * @param id socket id
   * @param room room name
   * @param fn callback
   */
  del(String id, String room, [Function fn]) {
    _sids.putIfAbsent(id, () -> {});
    _rooms.putIfAbsent(room, () -> {});
    _sids[id].remove(room);
    _rooms[room].remove(id);
    if (?fn) process.nextTick(fn.bind(null, null));
  }

  /**
   * Removes a socket from all rooms it's joined.
   *
   * @param String socket id
   */
  delAll(String id, fn) {
    var rooms = _sids[id];
    if (rooms != null) {
      for (var room in rooms) {
        _rooms[room].remove(id);
      }
    }
    _sids.remove(id);
  }

  /**
   * Broadcasts a packet.
   *
   * Options:
   *  - `flags` {Object} flags for this packet
   *  - `except` {Array} sids that should be excluded
   *  - `rooms` {Array} list of rooms to broadcast to
   *
   * @param {Object} packet object
   */
  broadcast(packet, opts) {
    var rooms = opts.rooms || [];
    var except = opts.except || [];
    var ids = {};
    var socket;

    if (rooms.length > 0) {
      for (var i = 0; i < rooms.length; i++) {
        var room = this.rooms[rooms[i]];
        if (!room) continue;
        for (var id in room) {
          if (ids[id] || ~except.indexOf(id)) continue;
          socket = this.nsp.connected[id];
          if (socket) {
            socket.packet(packet);
            ids[id] = true;
          }
        }
      }
    } else {
      for (var id in this.sids) {
        if (~except.indexOf(id)) continue;
        socket = this.nsp.connected[id];
        if (socket) socket.packet(packet);
      }
    }
  }
}