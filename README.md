# Duct

[Duct](http://github.com/petrh/duct) is clone of [Socket.IO](http://socket.io/) in Dart
which aims to be protocol-level compatible with the original implementation.

## Installing

First, add the library to the list of dependencies in your __pubspec.yaml__ file:

```yaml
duct:
    git: git://github.com/petrh/duct.git
```

Then, run `pub install` to install the package.

## Usage

Here is Duct used on server-side with Dart's built-in HTTP server:

```dart
#import('package:duct/duct.dart');

main() {
  var server = new HttpServer();
  var duct = new Duct(server);
  server.listen('127.0.0.1', 8080);
  
  duct.sockets.on('connection').then((socket) {
    socket.emit('news', { 'hello': 'world' });
    socket.on('my other event').then((data) {
      print(data);
    });
  }); 
}
```

The corresponding client-side code looks as follows:

```dart
#import('package:duct/duct.dart');

void main() {
  var socket = Duct.connect('http://localhost');
  socket.on('news').then((data) {
    print(data);
    socket.emit('my other event', { 'my': 'data' });
  });
}
```

## Contributing

Duct is at still at the early stage of development and all contribution
are more than welcome. Fork Duct on GitHub, make it awesomer and send a
pull request when it is ready.

Please note that one of the Duct's design goals is to use as many Dart
idioms as possible while retaining the Socket.IO compatibility.

## Contributors

* [petrh](http://github.com/petrh) ([+Petr Hosek](https://plus.google.com/u/0/110287390291502183886))

## License

Duct is licensed under the [BSD License](http://code.google.com/google_bsd_license.html).
