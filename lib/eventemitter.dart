library eventemitter;

import 'dart:isolate';

/////////////////////////////////////////////////////////

typedef void EventListener(Event event);

class EventTarget {
  Events get on => new Events(this);

  void addEventListener(String type, EventListener listener, [bool useCapture]);
  bool dispatchEvent(Event event);
  void removeEventListener(String type, EventListener listener, [bool useCapture]);
}

class EventListenerList {
  final Set<EventListener> _listenerList;

  EventListenerList(EventTarget _ptr, String _type) :
    _listenerList = new Set<EventListener>();

  EventListenerList add(EventListener listener) {
    _listenerList.add(listener);
    return this;
  }

  bool dispatch(Event event) {
    _listenerList.forEach((listener) => listener(event));
  }

  EventListenerList remove(EventListener listener) {
    _listenerList.remove(listener);
    return this;
  }
}

class Events {
  final EventTarget _ptr;
  final Map<String, EventListenerList> _listenerMap;

  Events(this._ptr) : _listenerMap = <String, EventListenerList>{};

  EventListenerList operator[](String type) {
    return _listenerMap.putIfAbsent(type,
        () => new EventListenerList(_ptr, type));
  }
}

class XXX extends Events {
  XXX(EventTarget _ptr) : super(_ptr);
  EventListenerList get click => this['click'];
}

//////////////////////////////////////////////////////////

typedef EventListener([arg1, arg2, arg3]);

abstract class EventEmitter {
  void addListener(String event, EventListener listener);
  void on(String event, EventListener listener);
  void once(String event, EventListener listener);
  void removeListener(String event, EventListener listener);
  List<EventListener> listeners(String event);
  void removeAllListeners(String event);
  void setMaxListeners(num n);
}

class _EventEmitter implements EventEmitter {

  Map<String, List<EventListener>> _events;
  //static List<SendPort> ports = const <SendPort>[];

  //ReceivePort _receiver;
  //SendPort _sender;

  static final num defaultMaxListeners = 10;
  num _maxListners;

  //EventEmitter() {
  //  _sender = this.port.toSendPort();
  //  ports.add(_sender);
  //}

  set maxListeners(num n) {
    _maxListeners = n;
  }

  bool emit(String event, [arg1, arg2, arg3]) {
    if (event == 'error') {
      if (_events == null) {
        if (arg1 is Exception) {
          throw arg1;
        } else {
          throw "Uncaught, unspecified 'error' event";
        }
      }
      return false;
    }

    if (_events == null) {
      return false;
    }
    var listeners = _events[event];
    if (listener == null) {
      return false;
    }

    listeners.forEach((listener) {
      return arg3 != null ?
          listener(arg1, arg2, arg3)
        : arg2 != null ?
          listener(arg1, arg2)
        : arg1 != null ?
          listener(arg1) :
          listener();
    });
    return true;
  }

  //static void start() {
  //  this.port.receive((message, SendPort replyTo) {
  //    ports.forEach((port) {
  //      if (port != replyTo) {
  //        port.send(message);
  //      }
  //    });
  //  });
  //}

  void addListener(String event, EventListener listener) {
    if (_events == null) {
      _events = <String, List<EventListener>>{};
    }

    emit('newListener', [event, listener]);
    _events.putIfAbsent(event, () => <EventListener>[]).add(listener);

    num m = _maxListeners != null ? _maxListeners : defaultMaxListeners;
    if (m > 0 && _events[event].length > m) {
      print('possible EventEmitter memory leak detected.'
            '$m listeners added. Use maxListeners to increase limit');
    }
  }

  void on(String event, EventListener listener) => addListener(event, listener);

  void once(String event, EventListener listener) {
    var callback = (args) {
      removeListener(event, callback);
      listener(args);
    }
    on(event, callback);
  }

  void removeListener(String event, EventListener listener) {
    if (_events == null || _events[event] == null) {
      return null;
    }

    int index = _events[event].indexOf(listener);
    if (index != -1) {
      _events[event].removeRange(index, 1);
    }
  }

  void removeAllListeners(String event) {
    if (_events == null || _events[event] == null) {
      return null;
    }

    if (_events.containsKey(event)) {
      _events[event].clear();
      _events.remove(event);
    }
  }

  List<EventListener> listeners(String event) {
    if (_events == null) {
      _events = <String, List<EventListener>>{};
    }
    return _events.putIfAbsent(event, () => <EventListener>[]);
  }

}
