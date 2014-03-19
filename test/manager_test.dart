import 'package:unittest/unittest.dart';
import '../lib/duct.dart';
import '../lib/manager.dart';

import 'dart:io';
import 'dart:isolate';

/**
 * Manager test.
 */
main() {
  int ports = 15100;

  test('test setting and getting a configuration flag', () {
    var port = ++ports;
    var server = new HttpServer();
    var io = Duct.listen(server);
    server.listen('127.0.0.1', port);

    io.set('a', 'b');
    expect(io.get('a'), equals('b'));

    port = ++ports;
    io = sio.listen(http.createServer());

    io.configure(() {
      io.set('a', 'b');
      io.enable('tobi');
    });

    expect(io.get('a'), equals('b'));
  });

  test('test enabling and disabling a configuration flag', () {
    var port = ++ports;
    var server = new HttpServer();
    var io = Duct.listen(server);
    server.listen('127.0.0.1', port);

    io.enable('flag');
    expect(io.enabled('flag'), isTrue);
    expect(io.disabled('flag'), isFalse);

    io.disable('flag');
    var port = ++ports
      , io = sio.listen(http.createServer());

    io.configure(() {
      io.enable('tobi');
    });

    expect(io.enabled('tobi'), isTrue);
  });

  test('test configuration callbacks with envs', () {
    var port = ++ports;
    var server = new HttpServer();
    var io = Duct.listen(server);
    server.listen('127.0.0.1', port);

    process.env.NODE_ENV = 'development';

    io.configure('production', () {
      io.set('ferret', 'tobi');
    });

    io.configure('development', () {
      io.set('ferret', 'jane');
    });

    io.get('ferret').should.eql('jane');
    done();
  });

  test('test configuration callbacks conserve scope', () {
    var port = ++ports;
    var server = new HttpServer();
    var io = Duct.listen(server);
    server.listen('127.0.0.1', port);
    var calls = 0;

    process.env.NODE_ENV = 'development';

    io.configure(() {
      this.should.eql(io);
      calls++;
    });

    io.configure('development', () {
      this.should.eql(io);
      calls++;
    });

    expect(calls, equals(2));
  });

  test('test configuration update notifications', () {
    var port = ++ports;
    var server = new HttpServer();
    var io = Duct.listen(server);
    server.listen('127.0.0.1', port);
    var calls = 0;

    io.on('set:foo', () {
      calls++;
    });

    io.set('foo', 'bar');
    io.set('baz', 'bar');

    expect(calls, equals(1));

    io.enable('foo');
    io.disable('foo');

    expect(calls, equals(3));
  });

  test('test that normal requests are still served', () {
    var server = http.createServer((req, res) {
      res.writeHead(200);
      res.end('woot');
    });

    var io = sio.listen(server)
      , port = ++ports
      , cl = client(port);

    server.listen(ports);

    cl.get('/socket.io', (res, data) {
      res.statusCode.should.eql(200);
      data.should.eql('Welcome to socket.io.');

      cl.get('/woot', (res, data) {
        res.statusCode.should.eql(200);
        data.should.eql('woot');

        cl.end();
        server.close();
      });
    });
  });

  test('test that you can disable clients', () {
    var port = ++ports
      , io = sio.listen(port)
      , cl = client(port);

    io.configure(() {
      io.disable('browser client');
    });

    cl.get('/socket.io/socket.io.js', (res, data) {
      res.statusCode.should.eql(200);
      data.should.eql('Welcome to socket.io.');

      cl.end();
      io.server.close();
    });
  });

  test('test handshake', () {
    var port = ++ports
      , io = sio.listen(port)
      , cl = client(port);

    cl.get('/socket.io/{protocol}/', (res, data) {
      res.statusCode.should.eql(200);
      data.should.match('/([^:]+):([0-9]+)?:([0-9]+)?:(.+)/');

      cl.end();
      io.server.close();
    });
  });

  test('test handshake with unsupported protocol version', () {
    var port = ++ports
      , io = sio.listen(port)
      , cl = client(port);

    cl.get('/socket.io/-1/', (res, data) {
      res.statusCode.should.eql(500);
      data.should.match('/Protocol version not supported/');

      cl.end();
      io.server.close();
    });
  });

  test('test authorization failure in handshake', () {
    var port = ++ports
      , io = sio.listen(port)
      , cl = client(port);

    io.configure(() {
      io.set('authorization', (data, fn) {
        fn(null, false);
      });
    });

    cl.get('/socket.io/{protocol}/', (res, data) {
      res.statusCode.should.eql(403);
      data.should.match('/handshake unauthorized/');

      cl.end();
      io.server.close();
    });
  });

  test('test a handshake error', () {
    var port = ++ports
      , io = sio.listen(port)
      , cl = client(port);

    io.configure(() {
      io.set('authorization', (data, fn) {
        fn(new Error());
      });
    });

    cl.get('/socket.io/{protocol}/', (res, data) {
      res.statusCode.should.eql(500);
      data.should.match('/handshake error/');

      cl.end();
      io.server.close();
    });
  });

  test('test that a referer is accepted for *:* origin', () {
    var port = ++ports
      , io = sio.listen(port)
      , cl = client(port);

    io.configure(() {
      io.set('origins', '*:*');
    });

    cl.get('/socket.io/{protocol}', { 'headers': { 'referer': 'http://foo.bar.com:82/something' } }, (res, data) {
      res.statusCode.should.eql(200);
      cl.end();
      io.server.close();
    });
  });

  test('test that valid referer is accepted for addr:* origin', () {
    var port = ++ports
      , io = sio.listen(port)
      , cl = client(port);

    io.configure(() {
      io.set('origins', 'foo.bar.com:*');
    });

    cl.get('/socket.io/{protocol}', { 'headers': { 'referer': 'http://foo.bar.com/something' } }, (res, data) {
      res.statusCode.should.eql(200);
      cl.end();
      io.server.close();
    });
  });

  test('test that a referer with implicit port 80 is accepted for foo.bar.com:80 origin', () {
    var port = ++ports
      , io = sio.listen(port)
      , cl = client(port);

    io.configure(() {
      io.set('origins', 'foo.bar.com:80');
    });

    cl.get('/socket.io/{protocol}', { 'headers': { 'referer': 'http://foo.bar.com/something' } }, (res, data) {
      res.statusCode.should.eql(200);
      cl.end();
      io.server.close();
    });
  });

  test('test that erroneous referer is denied for addr:* origin', () {
    var port = ++ports
      , io = sio.listen(port)
      , cl = client(port);

    io.configure(() {
      io.set('origins', 'foo.bar.com:*');
    });

    cl.get('/socket.io/{protocol}', { 'headers': { 'referer': 'http://baz.bar.com/something' } }, (res, data) {
      res.statusCode.should.eql(403);
      cl.end();
      io.server.close();
    });
  });

  test('test that valid referer port is accepted for addr:port origin', () {
    var port = ++ports
      , io = sio.listen(port)
      , cl = client(port);

    io.configure(() {
      io.set('origins', 'foo.bar.com:81');
    });

    cl.get('/socket.io/{protocol}', { 'headers': { 'referer': 'http://foo.bar.com:81/something' } }, (res, data) {
      res.statusCode.should.eql(200);
      cl.end();
      io.server.close();
    });
  });

  test('test that erroneous referer port is denied for addr:port origin', () {
    var port = ++ports
      , io = sio.listen(port)
      , cl = client(port);

    io.configure( () {
      io.set('origins', 'foo.bar.com:81');
    });

    cl.get('/socket.io/{protocol}', { 'headers': { 'referer': 'http://foo.bar.com/something' } }, (res, data) {
      res.statusCode.should.eql(403);
      cl.end();
      io.server.close();
    });
  });

  test('test handshake cross domain access control', () {
    var port = ++ports
      , io = sio.listen(port)
      , cl = client(port)
      , headers = {
            'Origin': 'http://example.org:1337'
          , 'Cookie': 'name=value'
        };

    cl.get('/socket.io/{protocol}/', { 'headers': headers }, (res, data) {
      res.statusCode.should.eql(200);
      res.headers['access-control-allow-origin'].should.eql('http://example.org:1337');
      res.headers['access-control-allow-credentials'].should.eql('true');

      cl.end();
      io.server.close();
    });
  });

  test('test limiting the supported transports for a manager', () {
    var port = ++ports
      , io = sio.listen(port)
      , cl = client(port);

    io.configure(() {
      io.set('transports', ['tobi', 'jane']);
    });

    cl.get('/socket.io/{protocol}/', (res, data) {
      res.statusCode.should.eql(200);
      data.should.match('/([^:]+):([0-9]+)?:([0-9]+)?:tobi,jane/');

      cl.end();
      io.server.close();
    });
  });

  test('test setting a custom close timeout', () {
    var port = ++ports
      , io = sio.listen(port)
      , cl = client(port);

    io.configure(() {
      io.set('close timeout', 66);
    });

    cl.get('/socket.io/{protocol}/', (res, data) {
      res.statusCode.should.eql(200);
      data.should.match('/([^:]+):([0-9]+)?:66?:(.*)/');

      cl.end();
      io.server.close();
    });
  });

  test('test setting a custom heartbeat timeout', () {
    var port = ++ports
      , io = sio.listen(port)
      , cl = client(port);

    io.configure(() {
      io.set('heartbeat timeout', 33);
    });

    cl.get('/socket.io/{protocol}/', (res, data) {
      res.statusCode.should.eql(200);
      data.should.match('/([^:]+):33:([0-9]+)?:(.*)/');

      cl.end();
      io.server.close();
    });
  });

  test('test disabling timeouts', () {
    var port = ++ports
      , io = sio.listen(port)
      , cl = client(port);

    io.configure(() {
      io.set('heartbeat timeout', null);
      io.set('close timeout', '');
    });

    cl.get('/socket.io/{protocol}/', (res, data) {
      res.statusCode.should.eql(200);
      data.should.match('/([^:]+)::?:(.*)/');

      cl.end();
      io.server.close();
    });
  });

  test('test disabling heartbeats', () {
    var port = ++ports
      , cl = client(port)
      , io = create(cl)
      , messages = 0
      , beat = false
      , ws;

    io.configure(() {
      io.disable('heartbeats');
      io.set('heartbeat interval', .05);
      io.set('heartbeat timeout', .05);
      io.set('close timeout', .05);
    });

    io.sockets.on('connection', (socket) {
      new Timer(io.get('heartbeat timeout') * 1000 + 100, (_) {
        socket.disconnect();
      });

      socket.on('disconnect', (reason) {
        expect(beat, isFalse);
        ws.finishClose();
        cl.end();
        io.server.close();
      });
    });

    cl.get('/socket.io/{protocol}/', (res, data) {
      res.statusCode.should.eql(200);
      data.should.match('/([^:]+)::[\.0-9]+:(.*)/');

      cl.handshake((sid) {
        ws = websocket(cl, sid);
        ws.on('message', (packet) {
          if (++messages == 1) {
            packet.type.should.eql('connect');
          } else if (packet.type == 'heartbeat'){
            beat = true;
          }
        });
      });
    });
  });

  test('no duplicate room members', () {
    var port = ++ports
      , io = sio.listen(port);

    Object.keys(io.rooms).length.should.equal(0);

    io.onJoin(123, 'foo');
    io.rooms.foo.length.should.equal(1);

    io.onJoin(123, 'foo');
    io.rooms.foo.length.should.equal(1);

    io.onJoin(124, 'foo');
    io.rooms.foo.length.should.equal(2);

    io.onJoin(124, 'foo');
    io.rooms.foo.length.should.equal(2);

    io.onJoin(123, 'bar');
    io.rooms.foo.length.should.equal(2);
    io.rooms.bar.length.should.equal(1);

    io.onJoin(123, 'bar');
    io.rooms.foo.length.should.equal(2);
    io.rooms.bar.length.should.equal(1);

    io.onJoin(124, 'bar');
    io.rooms.foo.length.should.equal(2);
    io.rooms.bar.length.should.equal(2);

    io.onJoin(124, 'bar');
    io.rooms.foo.length.should.equal(2);
    io.rooms.bar.length.should.equal(2);

    process.nextTick(() {
      io.server.close();
    });
  });

  test('test passing options directly to the Manager through listen', () {
    var port = ++ports
      , io = sio.listen(port, { 'resource': '/my resource', 'custom': 'opt' });

    io.get('resource').should.equal('/my resource');
    io.get('custom').should.equal('opt');
    process.nextTick(() {
      io.server.close();
    });
  });

  test('test disabling the log', () {
    var port = ++ports
      , io = sio.listen(port, { 'log': false })
      , _console = console.log
      , calls = 0;

    // the logger uses console.log to output data, override it to see if get's
    // used
    console.log = -> ++calls;

    io.log.debug('test');
    io.log.log('testing');

    console.log = _console;
    calls.should.equal(0);

    process.nextTick(() {
      io.server.close();
    });
  });

  test('test disabling logging with colors', () {
     var port = ++ports
      , io = sio.listen(port, { 'log colors': false })
      , _console = console.log
      , calls = 0;

    // the logger uses console.log to output data, override it to see if get's
    // used
    console.log = (data) {
      ++calls;
      data.indexOf('\033').should.equal(-1);
    };

    io.log.debug('test');
    io.log.log('testing');

    console.log = _console;
    calls.should.equal(2);

    process.nextTick(() {
      io.server.close();
    });
  });
}
