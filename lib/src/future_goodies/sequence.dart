part of future_goodies;

/**
 * Iterate through a list waiting for the [Future] to complete before moving next
 *
 * The [sequence] method iteraters over [iterable] by calling the [iterator], the
 * [iterator] must return a [Future], the [sequence] will wait for each future to
 * complete before moving to the next iteration, that way you make sure that your
 * list goes as a sequence.
 *
 * The returned value is a [Future] that will complete as an array containing the
 * results for all iterations (in the same input order). If any iteration fails
 * the result [Future] will fail with same error.
 *
 *     Future simpleDelay(value) => new Future.delayed(new Duration(milliseconds: 10));
 *
 *     sequence([1, 2, 3], (int v) => simpleDelay(v * 2)).then((List<int> values) {
 *       print(values); // [2, 4, 6]
 *     });
 */
Future<List> sequence(Iterable iterable, FutureFunction iterator) {
  return pipeline([], iterable, (list, value) {
    return iterator(value).then((result) => list..add(result));
  });
}