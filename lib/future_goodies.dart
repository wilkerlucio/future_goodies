library future_goodies;

import 'dart:async';

typedef Future Worker();
typedef Future FutureFunction(dynamic item);
typedef Future FutureReduceFunction(dynamic accumulator, dynamic value);

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

Future silentError(Future future) {
  return future.catchError((_) => null);
}

/**
 * Managers a [Future] worker poll
 *
 * The purpouse of this class is to help when you need to impose some limit
 * for [Future] calls. You just need to initialize with the limit number of
 * workers, then you call [push] passing a function that returns a [Future]
 * and with that the worker will manage to call this function when the poll
 * has space:
 *
 *     class SimpleJob {
 *       bool started = false;
 *       Completer completer = new Completer();
 *
 *       Future run() {
 *         started = true;
 *
 *         return completer.future;
 *       }
 *     }
 *
 *     FutureWorker worker = new FutureWorker(2);
 *
 *     SimpleJob job1 = new SimpleJob();
 *     SimpleJob job2 = new SimpleJob();
 *     SimpleJob job3 = new SimpleJob();
 *
 *     Future future1 = worker.push(job1.run); // will call right way since the poll is free
 *     Future future2 = worker.push(job2.run); // same as before, still have space
 *     Future future3 = worker.push(job3.run); // will be queued and hold
 *
 *     job1.started; // true
 *     job2.started; // true
 *     job3.started; // false
 *
 *     job1.completer.complete(null);
 *
 *     new Future.microtask(() {
 *       job3.started; // true
 *     });
 *
 *     future3.then((value) {
 *       value; // done, after the job3 completes
 *     });
 *
 *     job3.completer.complete('done');
 *
 * You probably going to use it when you wanna limit calls for a server and stuff
 * like that, so since adding a timeout is a common practice (to avoid the poll to
 * never get free slots) you can send a duration to timeout when constructing the
 * worker.
 *
 *     FutureWorker worker = new FutureWorker(2, timeout: new Duration(seconds: 15));
 */
class FutureWorker {
  int limit;
  Duration timeout;
  int _workingCount = 0;
  List<_FutureWorkerTask> _queue = [];

  FutureWorker(this.limit, {this.timeout});

  Future push(Worker worker) {
    if (_workingCount < limit) {
      return _runWorker(worker);
    } else {
      return _queueWorker(worker);
    }
  }

  Future _runWorker(Worker worker) {
    _workingCount++;

    return _wrapFuture(_setTimeout(worker()));
  }

  Future _queueWorker(Worker worker) {
    _FutureWorkerTask task = new _FutureWorkerTask(worker);
    _queue.add(task);

    return task.future;
  }

  Future _setTimeout(Future worker) {
    return timeout == null ? worker : worker.timeout(timeout);
  }

  Future _wrapFuture(Future worker) {
    return worker.then(_workerDone).catchError(_workerError);
  }

  dynamic _workerDone(value) {
    _workingCount--;

    if (_queue.length > 0)
      _processNext();

    return value;
  }

  void _processNext() {
    _FutureWorkerTask task = _queue.removeAt(0);

    task.complete(push(task.runner));
  }

  Future _workerError(err) {
    _workerDone(null);

    return new Future.error(err);
  }
}

class _FutureWorkerTask {
  Worker runner;
  Completer _completer = new Completer();

  _FutureWorkerTask(this.runner);

  Future get future => _completer.future;

  void complete(value) {
    _completer.complete(value);
  }
}