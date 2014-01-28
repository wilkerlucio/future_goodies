import 'package:barrier/dsl.dart';
import 'package:future_goodies/future_goodies.dart';
import 'dart:async';

final Function IDENTITY = (x) => x;

void runTests() {
  describe("Future Goodies", () {
    describe("sequence", () {
      Future testValidSequence(List input, List output, {Function mapFunction}) {
        if (mapFunction == null)
          mapFunction = IDENTITY;

        return sequence(input, mapFunction).then((res) => expect(res).eql(output));
      }

      it("resolves into a blank list when a blank list is given", () {
        return testValidSequence([], []);
      });

      it("resolves a list with promises results", () {
        return testValidSequence([1, 2], [3, 4], mapFunction: plusTwo);
      });

      it("rejects when a promise rejects", () {
        expect(sequence([1], throwError)).reject();
      });

      it("runs the tasks in sequence", () {
        List calls = [];
        Completer lastCompleter;

        Future seq = sequence([1, 2], (v) {
          lastCompleter = new Completer();
          calls.add(v);

          return lastCompleter.future;
        });

        expect(calls).eql([1]);

        lastCompleter.complete(calls.last);

        return lastCompleter.future.then((v) {
          expect(calls).eql([1, 2]);
        });
      });
    });
  });
}

plusTwo(v) => new Future.value(v + 2);

throwError(v) => throw new Exception("an error ocurred");

void main() => run(runTests);