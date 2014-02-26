import 'package:unittest/unittest.dart';
import 'package:future_goodies/future_goodies.dart';
import 'dart:async';

final Function IDENTITY = (x) => x;

void runTests() {
  group("Future Goodies", () {
    group("sequence", () {
      Future testValidSequence(List input, List output, {Function mapFunction}) {
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

Future plusTwo(v) => new Future.value(v + 2);

Future throwError(v) => throw new Exception("an error ocurred");

void main() => runTests();