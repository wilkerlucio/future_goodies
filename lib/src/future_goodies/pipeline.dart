part of future_goodies;

/**
 * Reduces a collection to a single value by iteratively combining each
 * element of the collection with an existing value using the provided
 * function. The [iterator] must return a [Future], and the iterator
 * will wait for it before moving on.
 *
 * If any iteration fails the result [Future] will fail with same error.
 *
 *     Future simpleDelay(value) => new Future.delayed(new Duration(milliseconds: 10));
 *
 *     pipeline('', ['a', 'b', 'c'], (String acc, String v) => simpleDelay(acc + v)).then((String result) {
 *       print(result); // 'abc'
 *     });
 */
Future pipeline(dynamic initial, Iterable list, FutureReduceFunction iterator) {
  if (list.isEmpty)
    return new Future.value(initial);

  return list.fold(new Future.value(initial), (Future current, value) {
    return current.then((acc) => iterator(acc, value));
  });
}