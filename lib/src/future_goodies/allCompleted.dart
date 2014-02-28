part of future_goodies;

/**
 * Given a list of futures, return all that completed successfully
 * after all of then responded
 *
 *     allCompleted([
 *      new Future.value(1),
 *      new Future.error('err'),
 *      new Future.value(2)]).then((List results) {
 *        print(results); // [1, 2]
 *      });
 *
 * This function is the inverse of [allRejected].
 */
Future<List> allCompleted(List<Future> futures) {
  return settle(futures).then((List<SettleResult> settles) {
    return settles
        .where((s) => s.isCompleted)
        .map((s) => s.result);
  });
}