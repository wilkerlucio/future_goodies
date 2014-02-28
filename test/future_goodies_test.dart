import 'package:unittest/unittest.dart';
import 'package:future_goodies/future_goodies.dart';
import 'dart:async';
import 'dart:math';

final Function IDENTITY = (x) => x;

void runTests() {
  group("Future Goodies", () {
    group("sequence", () {
      void testValidSequence(List input, List output, {Function mapFunction}) {
        if (mapFunction == null)
          mapFunction = IDENTITY;

        expect(sequence(input, mapFunction), completion(equals(output)));
      }

      test("resolves into a blank list when a blank list is given", () {
        testValidSequence([], []);
      });

      test("resolves a list with future results", () {
        testValidSequence([1, 2], [3, 4], mapFunction: plusTwo);
      });

      test("rejects when a future rejects", () {
        expect(sequence([1], throwError), throws);
      });

      test("runs the tasks in sequence", () {
        List calls = [];
        Completer lastCompleter;

        Future seq = sequence([1, 2], (v) {
          lastCompleter = new Completer();
          calls.add(v);

          return lastCompleter.future;
        });

        return new Future.microtask(() {
          expect(calls, equals([1]));

          lastCompleter.complete(calls.last);

          return lastCompleter.future.then((v) {
            expect(calls, equals([1, 2]));
          });
        });
      });
    });

    group("pipeline", () {
      test("resolves to initial when input is blank", () {
        expect(pipeline(1, [], (acc, value) {}), completion(1));
      });

      test("resolves to the returned value", () {
        expect(pipeline(null, [1], (acc, value) => value), completion(equals(1)));
      });

      test("accumulates the inputs", () {
        expect(pipeline(0, [1, 2], (acc, value) => acc + value), completion(equals(3)));
      });
    });

    group('silentError', () {
      test('resolves the original value when the future completes', () {
        expect(silentError(new Future.value('x')), completion('x'));
      });

      test('resolves to null when the future throws an error', () {
        Completer completer = new Completer();
        completer.completeError(new Exception('err'));

        expect(silentError(completer.future), completion(isNull));
      });
    });

    group('FutureWorker', () {
      test('runs a job direct when the worker count is under limit', () {
        FutureWorker worker = new FutureWorker(1);
        SimpleJob job = new SimpleJob();

        Future<String> future = worker.push(job.run);

        expect(job.started, isTrue);

        job.completer.complete('test');

        expect(future, completion('test'));
      });

      test('doesn\'t run if the workers are full', () {
        FutureWorker worker = new FutureWorker(1);

        SimpleJob secondJob = new SimpleJob();

        worker.push(new SimpleJob().run);
        worker.push(secondJob.run);

        expect(secondJob.started, isFalse);
      });

      test('run the job when the queue has added limit', () {
        FutureWorker worker = new FutureWorker(1);

        SimpleJob job = new SimpleJob();
        SimpleJob secondJob = new SimpleJob();

        Future future = worker.push(job.run);
        worker.push(secondJob.run);

        expect(secondJob.started, isFalse);

        job.completer.complete(null);

        return future.then((value) {
          expect(secondJob.started, isTrue);
        });
      });

      test('run the job when the queue has added limit for a failed task', () {
        FutureWorker worker = new FutureWorker(1);

        SimpleJob job = new SimpleJob();
        SimpleJob secondJob = new SimpleJob();

        Future future = worker.push(job.run);
        worker.push(secondJob.run);

        expect(secondJob.started, isFalse);

        job.completer.completeError(new Exception('bla'));

        return future.catchError((err) {
          expect(secondJob.started, isTrue);
        });
      });

      test('run all the jobs', () {
        FutureWorker worker = new FutureWorker(1);

        SimpleJob job = new SimpleJob();
        SimpleJob secondJob = new SimpleJob();

        worker.push(job.run);
        worker.push(secondJob.run);

        job.completer.complete('one');
        secondJob.completer.complete('two');

        expect(secondJob.completer.future, completion('two'));
      });

      test('timeout when asked', () {
        FutureWorker worker = new FutureWorker(1, timeout: new Duration(milliseconds: 10));

        SimpleJob job = new SimpleJob();
        SimpleJob secondJob = new SimpleJob();

        silentError(worker.push(job.run));
        silentError(worker.push(secondJob.run));

        return new Future.delayed(new Duration(milliseconds: 50), () {
          expect(secondJob.started, isTrue);
        });
      });
    });

    group('settle', () {
      test('returns on empty list for empty input', () {
        expect(settle([]), completion([]));
      });

      test('maps a list of future into SettleResults', () {
        return settle([new Future.value('ok'), new Future.error('err')]).then((List<SettleResult> statuses) {
          expect(statuses[0], new SettleResult(SettleResult.COMPLETED, result: 'ok'));
          expect(statuses[1], new SettleResult(SettleResult.REJECTED, error: 'err'));
        });
      });

      group('SettleResult', () {
        test('return completed result when the future completes', () {
          expect(SettleResult.settle(new Future.value('ok')), completion(new SettleResult(SettleResult.COMPLETED, result: 'ok')));
        });

        test('return rejected result when the future completes', () {
          Exception error = new Exception('err');

          expect(SettleResult.settle(new Future.error(error)), completion(new SettleResult(SettleResult.REJECTED, error: error)));
        });

        test('toString for completed', () {
          expect(new SettleResult(SettleResult.COMPLETED, result: 'ok').toString(), 'SettleResult status:#completed result:ok');
        });

        test('toString for rejected', () {
          expect(new SettleResult(SettleResult.REJECTED, error: 'err').toString(), 'SettleResult status:#rejected error:err');
        });
      });
    });

    group('unfold', () {
      test('instant unfold', () {
        List<int> calls = [];

        Function unspool = (seed) {
          return [seed, null];
        };

        Function condition = (value) {
          return calls.length > 0;
        };

        Function process = (value) {
          calls.add(value);
        };

        return unfold(unspool, condition, process, 0).then((_) {
          expect(calls, [0]);
        });
      });

      test('incremental checking', () {
        int count = 0;

        Function unspool = (seed) {
          return [seed, seed + 1];
        };

        Function condition = (value) {
          return count > 10;
        };

        Function process = (value) {
          count += value;
        };

        return unfold(unspool, condition, process, 0).then((_) {
          expect(count, 15);
        });
      });

      test('seed as a future', () {
        int count = 0;

        Function unspool = (seed) {
          return [seed, seed + 1];
        };

        Function condition = (value) {
          return count > 10;
        };

        Function process = (value) {
          count += value;
        };

        return unfold(unspool, condition, process, new Future.value(0)).then((_) {
          expect(count, 15);
        });
      });

      test('unspool returns value as future', () {
        int count = 0;

        Function unspool = (seed) {
          return [new Future.value(seed), seed + 1];
        };

        Function condition = (value) {
          return count > 10;
        };

        Function process = (value) {
          count += value;
        };

        return unfold(unspool, condition, process, 0).then((_) {
          expect(count, 15);
        });
      });

      test('incremental unspool future return', () {
        int count = 0;

        Function unspool = (seed) {
          return new Future.value([seed, seed + 1]);
        };

        Function condition = (value) {
          return count > 10;
        };

        Function process = (value) {
          count += value;
        };

        return unfold(unspool, condition, process, 0).then((_) {
          expect(count, 15);
        });
      });

      test('process can delay the run', () {
        List<int> calls = [];

        Function unspool = (seed) {
          return [seed, seed + 1];
        };

        Function condition = (value) {
          return calls.length == 5;
        };

        Function process = (value) {
          Random random = new Random();
          return new Future.delayed(new Duration(milliseconds: random.nextInt(10)), () {
            calls.add(value);
          });
        };

        return unfold(unspool, condition, process, 0).then((_) {
          expect(calls, [0, 1, 2, 3, 4]);
        });
      });
    });

    group('unfoldList', () {
      test('process results by concatenating results', () {
        Function unspool = (seed) {
          return [new Future.value(seed), seed + 1];
        };

        Function condition = (value) {
          return value == 5;
        };

        return unfoldList(unspool, condition, 0).then((List results) {
          expect(results, [0, 1, 2, 3, 4]);
        });
      });
    });

    group('allCompleted', () {
      test('filter completed futures and return then', () {
        expect(allCompleted([new Future.value(1), new Future.error('err'), new Future.value(2)]), completion([1, 2]));
      });
    });

    group('allRejected', () {
      test('filter rejected futures and return then', () {
        expect(allRejected([new Future.value(1), new Future.error('err'), new Future.value(2)]), completion(['err']));
      });
    });
  });
}

class SimpleJob {
  bool started = false;
  Completer completer = new Completer();

  Future run() {
    started = true;

    return completer.future;
  }
}

Future silentError(Future future) {
  return future.catchError((_) => null);
}

Future plusTwo(v) => new Future.value(v + 2);

Future throwError(v) => throw new Exception("an error ocurred");

void main() => runTests();