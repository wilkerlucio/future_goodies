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

      test("resolves a list with promises results", () {
        testValidSequence([1, 2], [3, 4], mapFunction: plusTwo);
      });

      test("rejects when a promise rejects", () {
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

        expect(calls, equals([1]));

        lastCompleter.complete(calls.last);

        return lastCompleter.future.then((v) {
          expect(calls, equals([1, 2]));
        });
      });
    });

    group("pipeline", () {
      test("resolves to null when input is blank", () {
        expect(pipeline(null, [], (acc, value) {}), completion(isNull));
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
  });
}

Future plusTwo(v) => new Future.value(v + 2);

Future throwError(v) => throw new Exception("an error ocurred");

void main() => runTests();