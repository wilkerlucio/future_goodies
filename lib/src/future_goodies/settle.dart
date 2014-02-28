part of future_goodies;

/**
 * Makes a list of futures always completes, returning the state of
 * the completion.
 *
 *     settle([new Future.value('hello'), new Future.error('err')]).then((List<SettleResult> results) {
 *       results[0]; // <SettleResult status:#completed result:hello>
 *       results[1]; // <SettleResult status:#rejected error:err>
 *     });
 *
 * If you wanna do it for a single future, check [SettleResult.settle]
 */
Future<List<SettleResult>> settle(List<Future> futures) => Future.wait(futures.map(SettleResult.settle));

class SettleResult {
  static final COMPLETED = #_completed;
  static final REJECTED = #_rejected;

  final Symbol status;
  final dynamic result;
  final dynamic error;

  SettleResult(this.status, {this.result, this.error});

  bool get isCompleted => status == COMPLETED;
  bool get isRejected => status == REJECTED;

  /**
   * Wraps a future to always completes with a SettleResult
   *
   * This function will return a [Future], this future will
   * be an instance of [SettleResult].
   *
   * Given the original future has completed with success,
   * the [SettleResult] will have the [status] value of
   * [COMPLETED] and the [result] will have the completion value.
   *
   * Given the original future fails, the [SettleResult] will
   * have the [status] as [REJECTED] and the `error` will contain
   * the thrown error.
   *
   *     SettleResult.settle(new Future.value('ok')).then((SettleResult res) {
   *      res.status; // SettleResult.COMPLETED
   *      res.result; // 'ok'
   *      res.error; // null
   *     });
   *
   *     SettleResult.settle(new Future.error('err')).then((SettleResult res) {
   *       res.status; // SettleResult.REJECTED
   *       res.result; // null
   *       res.error; // 'err'
   *     });
   */
  static Future settle(Future input) {
    return input.then(_buildCompleted, onError: _buildError);
  }

  static SettleResult _buildCompleted(dynamic value) => new SettleResult(COMPLETED, result: value);
  static SettleResult _buildError(dynamic error) => new SettleResult(REJECTED, error: error);

  operator ==(SettleResult res) {
    return status == res.status
        && result == res.result
        && error  == res.error;
  }

  String toString() {
    if (status == COMPLETED) {
      return "SettleResult status:#completed result:$result";
    } else if (status == REJECTED) {
      return "SettleResult status:#rejected error:$error";
    } else {
      return 'Invalid status:$status';
    }
  }
}