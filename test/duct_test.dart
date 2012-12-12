import 'package:unittest/unittest.dart';
import '../lib/duct.dart';

import 'dart:io';

/**
 * Test.
 */
main() {
  int ports = 15000;

  test('test that protocol version is present', () {
    expect(Duct.protocol, isPositive);
  });

  test('test that default transports are present', () {
    expect(Manager.defaultTransports, isNot(isEmpty));
  });

  test('test that version is present', () {
    expect(Duct.version, matches("([0-9]+)\.([0-9]+)\.([0-9]+)"));
  });

  test('test listening with a port', () {
    var client = new HttpClient();
    var server = create(client);
    
    expect(server, new isInstanceOf<HttpServer>());

    var conn = client.get('127.0.0.1', ++ports, '/');
    conn.onResponse = (HttpClientResponse res) {
      expect(res.statusCode, equals(HttpStatus.OK));
      var input = res.inputStream;
      input.onData = () {
        var data = input.read();
        var text = new String.fromCharCodes(data);
        expect(text, equals('Welcome to socket.io.'));
      };
      input.onClosed = () {
        client.shutdown();
        server.close();
      };
    };
  });

  test('test listening with a server', () {
    var server = new HttpServer();
    var client = new HttpClient();
    
    var port = ++ports;
    
    var duct = Duct.listen(server);
    server.listen('127.0.0.1', port);
    
    var conn = client.get('127.0.0.1', port, '/socket.io');
    conn.onResponse = (HttpClientResponse res) {
      expect(res.statusCode, equals(HttpStatus.OK));
      var input = res.inputStream;
      input.onData = () {
        var data = input.read();
        var text = new String.fromCharCodes(data);
        expect(text, equals('Welcome to socket.io.'));
      };
      input.onClosed = () {
        client.shutdown();
        server.close();
      };
    };
  });

  test('test listening with no arguments listens on 80', () {
    try {
      var server = Duct.listen();
      var client = new HttpClient();
      
      var conn = client.get('127.0.0.1', 80, '/socket.io');
      conn.onResponse = (HttpClientResponse res) {
        expect(res.statusCode, equals(HttpStatus.OK));
        client.shutdown();
        server.close();
      };
    } catch (e) {
      expect(e, matches('/EACCES'));
    }
  });
}