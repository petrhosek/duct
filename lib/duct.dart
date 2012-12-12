library duct;

import 'dart:io';

import 'manager.dart';
import 'namespace.dart';
import 'parser.dart';
import 'socket.dart';
import 'store.dart';
import 'transport.dart';

class Duct {
  /**
   * Version.
   */
  static const String version = '0.0.1';
  
  /**
   * Supported protocol version.
   */
  static const int protocol = 1;
  
  /**
   * Attaches a manager.
   *
   * @param {HTTPServer/Number} a HTTP/S server or a port number to listen on.
   * @param {Object} opts to be passed to Manager and/or http server
   * @param {Function} callback if a port is supplied
   * @api public
   */
  static listen([HttpServer server, int port = 80, options = const {}]) {
    if (server == null) {
      var server = new HttpServer();
      
      //default response
      server.defaultRequestHandler = (HttpRequest req, HttpResponse res) {
        res.statusCode = HttpStatus.OK;
        res.outputStream.write('Welcome to socket.io'.charCodes);
      };
      
      server.listen('127.0.0.1', port);
    }
    
    // otherwise assume a http/s server
    return new Manager(server, options);
  }
}