part of future_goodies;

/**
 * Given a list of futures, return all that got error
 *
 *     allRejected([
 *      new Future.value(1),
 *      new Future.error('err'),
 *      new Future.value(2)]).then((List results) {
 *        print(results); // ['err']
 *      });
 *
 * This function is the inverse of [allCompleted].
 */
Future<List> allRejected(futures) {
  return settle(futures).then((settles) {
    return settles
        .where((s) => s.isRejected)
        .map((s) => s.error);
  });
}