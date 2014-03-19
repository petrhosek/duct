library packet;

class Packet implements Map<String, Object> {
  Map<String, Object> _content;

  /**
   * Returns whether this map contains the given [value].
   */
  bool containsValue(Object value) {
    _content.containsValue(value);
  }

  /**
   * Returns whether this map contains the given [key].
   */
  bool containsKey(String key) {
    return _content.containsKey(key);
  }

  /**
   * Returns the value for the given [key] or null if [key] is not
   * in the map. Because null values are supported, one should either
   * use containsKey to distinguish between an absent key and a null
   * value, or use the [putIfAbsent] method.
   */
  Object operator [](String key) {
    return _content[key];
  }

  /**
   * Associates the [key] with the given [value].
   */
  void operator []=(String key, Object value) {
    _content[key] = value;
  }

  /**
   * If [key] is not associated to a value, calls [ifAbsent] and
   * updates the map by mapping [key] to the value returned by
   * [ifAbsent]. Returns the value in the map.
   */
  Object putIfAbsent(String key, Object ifAbsent()) {
    return _content.putIfAbsent(key, ifAbsent);
  }

  /**
   * Removes the association for the given [key]. Returns the value for
   * [key] in the map or null if [key] is not in the map. Note that values
   * can be null and a returned null value does not always imply that the
   * key is absent.
   */
  Object remove(String key) {
    _content.remove(key);
  }

  /**
   * Removes all pairs from the map.
   */
  void clear() {
    _content.clear();
  }

  /**
   * Applies [f] to each {key, value} pair of the map.
   */
  void forEach(void f(String key, Object value)) {
    _content.forEach(f);
  }

  /**
   * Returns a collection containing all the keys in the map.
   */
  Collection<String> get keys => _content.keys;

  /**
   * Returns a collection containing all the values in the map.
   */
  Collection<Object> get values => _content.values;

  /**
   * The number of {key, value} pairs in the map.
   */
  int get length => _content.length;

  /**
   * Returns true if there is no {key, value} pair in the map.
   */
  bool get isEmpty => _content.isEmpty;
}