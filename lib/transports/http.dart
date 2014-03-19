library http;

import 'dart:io';

import '../parser.dart';
import '../transport.dart';

class HttpTransport extends Transport {
  HttpResponse _response;

  /**
   * Handles request.
   */
  handleRequest(HttpRequest request, HttpResponse response) {
    // Always set the response in case an error is returned to the client
    _response = response;

    if (request.method == 'POST') {
      StringBuffer buffer = new StringBuffer();
      var origin = request.headers.origin;
      var headers = { 'Content-Length': 1, 'Content-Type': 'application/javascript; charset=UTF-8' };
      var self = this;

      var inputStream = request.inputStream;

      inputStream.onData = () {
        buffer.add(inputStream.read());

        if (buffer.length >= manager.get('destroy buffer size')) {
          buffer.clear();
          request.session().destroy();
        }
      };

      // prevent memory leaks for uncompleted requests
      inputStream.onClosed = () {
        buffer.clear();
        onClose();
      };

      inputStream.onEnd = () {
        response.statusCode = HttpStatus.OK;
        response.headers = headers;

        var outputStream = response.outputStream;
        outputStream.writeString('1');
        outputStream.close();

        onData(self.postEncoded ? qs.parse(buffer).d : buffer);
      };

      if (origin) {
        // https://developer.mozilla.org/En/HTTP_Access_Control
        headers['Access-Control-Allow-Origin'] = origin;
        headers['Access-Control-Allow-Credentials'] = 'true';
      }
    } else {
      super.handleRequest(request, response);
    }
  }

  /**
   * Handles data payload.
   */
  onData(data) {
    var messages = Parser.decodePayload(data);
    log.fine('$name received data packet $data');

    messages.forEach((message) => onMessage(message));
  }

  /**
   * Closes the request-response cycle
   */
  doClose() => _response.outputStream.close();

  /**
   * Writes a payload of messages
   */
  payload(message) => write(Parser.encodePayload(message));

}
