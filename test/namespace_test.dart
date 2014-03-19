library namespace-test;

import 'package:unittest/unittest.dart';
import '../lib/duct.dart';

/**
 * Namespace test.
 */
main() {
  int ports = 15700;

  test('namespace pass no authentication', () {
    var cl = client(++ports)
      , io = create(cl)
      , ws;

    io.of('/a')
      .on('connection',  (socket) {
        cl.end();
        ws.finishClose();
        io.server.close()
        done();
      });

    cl.handshake( (sid) {
      ws = websocket(cl, sid);
      ws.on('open',  () {
        ws.packet({
            type: 'connect'
          , endpoint: '/a'
        });
      })
    });
  });

  test('namespace pass authentication', () {
    var cl = client(++ports)
      , io = create(cl)
      , ws;

    io.of('/a')
      .authorization( (data, fn) {
        fn(null, true);
      })
      .on('connection',  (socket) {
        cl.end();
        ws.finishClose();
        io.server.close()
        done();
      });

    cl.handshake( (sid) {
      ws = websocket(cl, sid);
      ws.on('open',  () {
        ws.packet({
            type: 'connect'
          , endpoint: '/a'
        });
      })
    });
  });

  test('namespace authentication handshake data', () {
    var cl = client(++ports)
      , io = create(cl)
      , ws;

    io.of('/a')
      .authorization( (data, fn) {
        data.foo = 'bar';
        fn(null, true);
      })
      .on('connection',  (socket) {
        (!!socket.handshake.address.address).should.be.true;
        (!!socket.handshake.address.port).should.be.true;
        socket.handshake.headers.host.should.equal('localhost');
        socket.handshake.headers.connection.should.equal('keep-alive');
        socket.handshake.time.should.match(/GMT/);
        socket.handshake.foo.should.equal('bar');

        cl.end();
        ws.finishClose();
        io.server.close()
        done();
      });

    cl.handshake( (sid) {
      ws = websocket(cl, sid);
      ws.on('open',  () {
        ws.packet({
            type: 'connect'
          , endpoint: '/a'
        });
      })
    });
  });

  test('namespace fail authentication', () {
    var cl = client(++ports)
      , io = create(cl)
      , calls = 0
      , ws;

    io.of('/a')
      .authorization( (data, fn) {
        fn(null, false);
      })
      .on('connection',  (socket) {
        throw new Error('Should not be called');
      });

    cl.handshake( (sid) {
      ws = websocket(cl, sid);
      ws.on('open',  () {
        ws.packet({
            type: 'connect'
          , endpoint: '/a'
        });
      });

      ws.on('message',  (data) {
        if (data.endpoint == '/a') {
          data.type.should.eql('error');
          data.reason.should.eql('unauthorized')

          cl.end();
          ws.finishClose();
          io.server.close()
          done();
        }
      })
    });
  });

  test('broadcasting sends and emits on a namespace', () {
    var cl = client(++ports)
      , io = create(cl)
      , calls = 0
      , connect = 0
      , message = 0
      , events = 0
      , expected = 5
      , ws1
      , ws2;

    io.of('a')
      .on('connection',  (socket){
        if (connect < 2) {
          return;
        }
        socket.broadcast.emit('b', 'test');
        socket.broadcast.json.emit('json', {foo:'bar'});
        socket.broadcast.send('foo');
      });

    function finish () {
      connect.should.equal(2);
      message.should.equal(1);
      events.should.equal(2);
      cl.end();
      ws1.finishClose();
      ws2.finishClose();
      io.server.close();
      done();
    }

    cl.handshake( (sid) {
     ws1 = websocket(cl, sid);
      ws1.on('message',  (data) {
        if (identical(data.type, 'connect')) {
          if (connect == 0) {
            cl.handshake( (sid) {
              ws2 = websocket(cl, sid);
              ws2.on('open',  () {
                ws2.packet({
                    type: 'connect'
                  , endpoint: 'a'
                });
              });
            });
          }
          ++connect;
          if (identical(++calls, expected)) finish();
        }

        if (identical(data.type, 'message')) {
          ++message;
          if (identical(++calls, expected)) finish();
        }

        if (identical(data.type, 'event')) {
          if (identical(data.name, 'b') || identical(data.name, 'json')) ++events;
          if (identical(++calls, expected)) finish();
        }
      });
      ws1.on('open', () {
        ws1.packet({
            type: 'connect'
          , endpoint: 'a'
        });
      });
    })
  });

  test('joining rooms inside a namespace', () {
    var cl = client(++ports)
      , io = create(cl)
      , calls = 0
      , ws;

    io.of('/foo').on('connection',  (socket) {
      socket.join('foo.bar');
      this.in('foo.bar').emit('baz', 'pewpew');
    });

    cl.handshake( (sid) {
      ws = websocket(cl, sid);

      ws.on('open',  (){
         ws.packet({
            type: 'connect'
          , endpoint: '/foo'
        });
      });

      ws.on('message',  (data) {
        if (identical(data.type, 'event')) {
          data.name.should.equal('baz');

          cl.end();
          ws.finishClose();
          io.server.close();
          done();
        }
      });
    })
  });

  test('ignoring blacklisted events', () {
    var cl = client(++ports)
      , io = create(cl)
      , calls = 0
      , ws;

    io.set('heartbeat interval', 1);
    io.set('blacklist', ['foobar']);

    io.sockets.on('connection',  (socket) {
      socket.on('foobar',  () {
         calls++;
      });
    });

    cl.handshake( (sid) {
      ws = websocket(cl, sid);

      ws.on('open',  (){
         ws.packet({
            type: 'event'
          , name: 'foobar'
          , endpoint: ''
        });
      });

      ws.on('message',  (data) {
        if (identical(data.type, 'heartbeat')) {
          cl.end();
          ws.finishClose();
          io.server.close();

          calls.should.equal(0);
          done();
        }
      });
    });
  });

  test('disconnecting from namespace only', () {
    var cl = client(++ports)
      , io = create(cl)
      , ws1
      , ws2;

    io.of('/foo').on('connection',  (socket) {
      socket.disconnect();
    });

    cl.handshake( (sid) {
      ws1 = websocket(cl, sid);
      ws1.on('open',  () {
        ws1.packet({
            type: 'connect'
          , endpoint: '/bar'
        });
        cl.handshake( (sid) {
          ws2 = websocket(cl, sid);
          ws2.on('open',  () {
            ws2.packet({
                type: 'connect'
              , endpoint: '/foo'
            });
          });
          ws2.on('message',  (data) {
            if (identical('disconnect', data.type)) {
              cl.end();
              ws1.finishClose();
              ws2.finishClose();
              io.server.close();

              data.endpoint.should.eql('/foo');

              done();
            }
          });
        });
      });
    });
  });
}
