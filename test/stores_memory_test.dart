import '../lib/store.dart';
import '../lib/stores/memory.dart';

import 'package:unittest/unittest.dart';

import 'dart:math';
import 'dart:isolate';

/**
 * Memory store test.
 */
main() {
  test('test storing data for a client', () {
    var store = new MemoryStore();
    var client = store.client('test');

    expect(client.id, equals('test'));

    client.set('a', 'b').then(expectAsync1(_) {
      client.get('a').then(expectAsync1(val) {
        expect(val, equals('b'));

        client.has('a').then(expectAsync1(has) {
          expect(has, isTrue);

          client.has('b').then(expectAsync1(has) {
            expect(has, isFalse);

            client.del('a').then(expectAsync1(_) {
              client.has('a').then(expectAsync1(has) {
                expect(has, isFalse);

                client.set('b', 'c').then(expectAsync1(_) {
                  client.set('c', 'd').then(expectAsync1(_) {
                    client.get('b').then(expectAsync1(val) {
                      expect(val, equals('c'));

                      client.get('c').then(expecetAsync1(val) {
                        expect(val, equals('d'));

                        store.destroy();
                      });
                    });
                  });
                });
              });
            });
          });
        });
      });
    });
  });

  test('test cleaning up clients data', () {
    var random = new Random();
    var rand1 = '${((random.nextDouble() * new Date.now().millisecondsSinceEpoch).toInt() | 0).abs()}';
    var rand2 = '${((random.nextDouble() * new Date.now().millisecondsSinceEpoch).toInt() | 0).abs()}';

    var store = new MemoryStore();
    var client1 = store.client(rand1);
    var client2 = store.client(rand2);

    client1.set('a', 'b').then(expectAsync1(_) {
      client2.set('c', 'd').then(expectAsync1(_) {
        client1.has('a').then(expectAsync1(has) {
          expect(has, isTrue);

          client2.has('c').then(expectAsync1(has) {
            expect(has, isTrue);

            store.destroy();

            var newstore = new MemoryStore();
            var newclient1 = newstore.client(rand1);
            var newclient2 = newstore.client(rand2);

            newclient1.has('a').then(expectAsync1(has) {
              expect(has, isFalse);

              newclient2.has('c').then(expectAsync1(has) {
                expect(has, isFalse);

                newstore.destroy();
              });
            });
          });
        });
      });
    });
  });

  test('test cleaning up a particular client', () {
    var random = new Random();
    var rand1 = '${((random.nextDouble() * new Date.now().millisecondsSinceEpoch).toInt() | 0).abs()}';
    var rand2 = '${((random.nextDouble() * new Date.now().millisecondsSinceEpoch).toInt() | 0).abs()}';

    var store = new MemoryStore();
    var client1 = store.client(rand1);
    var client2 = store.client(rand2);

    client1.set('a', 'b').then(expectAsync1(_) {
      client2.set('c', 'd').then(expectAsync1(_) {
        client1.has('a').then(expectAsync1(has) {
          expect(has, isTrue);

          client2.has('c').then(expectAsync1(has) {
            expect(has, isTrue);

            expect(store.clients, contains(rand1));
            expect(store.clients, contains(rand2));
            store.destroyClient(rand1);

            expect(store.clients, isNot(contains(rand1)));
            expect(store.clients, contains(rand2));

            client1.has('a').then(expectAsync1(has) {
              expect(has, isFalse);

              store.destroy();
            });
          });
        });
      });
    });
  });

  test('test destroy expiration', () {
    var store = new MemoryStore();
    var id = '${((new Random().nextDouble() * new Date.now().millisecondsSinceEpoch).toInt() | 0).abs()}';
    var client = store.client(id);

    client.set('a', 'b').then(expectAsync1(_) {
      store.destroyClient(id, 1);

      new Timer(500, (_) {
        client.get('a').then(expectAsync1(val) {
          expect(val, equals('b'));
        });
      });

      new Timer(1900, (_) {
        client.get('a').then(expectAsync1(val) {
          expect(val, isNull);

          store.destroy();
        });
      });
    });
  });
}
