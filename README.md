Dart Future Goodies
==============

[![Build Status](https://drone.io/github.com/wilkerlucio/future_goodies/status.png)](https://drone.io/github.com/wilkerlucio/future_goodies/latest)

Future goodies for Dart.

Install
-------

Just add to your `pubspec.yaml`:

```yaml
dependencies:
  future_goodies: any
```

Usage
-----

Future goodies provides some helper functions to deal with Future management. Here we going to document each function.

### sequence

This function iteraters over a collection by calling the `iterator`, this `iterator` can either return a value, or a `Future`, if a `Future` is returned, the iteration will wait until it completes before running the next iteration. This function returns a `Future`, that will resolve as a `List` containing the result values (all resolved) of the iteration. If any iteration fails (sync or async) the `sequence` will stop and the `Future` returned by it will fail with the error.

```dart
import 'package:future_goodies/future_goodies.dart';
import 'dart:async';

Future delayed(value) {
  return new Future.delayed(new Duration(milliseconds: 20), () => value));
}

void main() {
  Future<List<int>> result = sequence([1, 2, 3, 4], (n) => delayed(n * 2));

  result.then((List<int> values) {
    print(values); // [2, 4, 6, 8]
  });
}
```

### pipeline

Reduces a collection to a single value by iteratively combining each
element of the collection with an existing value using the provided
function. The iterator must return a Future, and the iterator
will wait for it before moving on.

If any iteration fails the result Future will fail with same error.

```dart
Future simpleDelay(value) => new Future.delayed(new Duration(milliseconds: 10));

pipeline('', ['a', 'b', 'c'], (String acc, String v) => simpleDelay(acc + v)).then((String result) {
  print(result); // 'abc'
});
```

### FutureWorker

Managers a Future worker poll

The purpouse of this class is to help when you need to impose some limit
for Future calls. You just need to initialize with the limit number of
workers, then you call push passing a function that returns a Future
and with that the worker will manage to call this function when the poll
has space:

```dart
class SimpleJob {
  bool started = false;
  Completer completer = new Completer();

  Future run() {
    started = true;

    return completer.future;
  }
}

FutureWorker worker = new FutureWorker(2);

SimpleJob job1 = new SimpleJob();
SimpleJob job2 = new SimpleJob();
SimpleJob job3 = new SimpleJob();

Future future1 = worker.push(job1.run); // will call right way since the poll is free
Future future2 = worker.push(job2.run); // same as before, still have space
Future future3 = worker.push(job3.run); // will be queued and hold

job1.started; // true
job2.started; // true
job3.started; // false

job1.completer.complete(null);

new Future.microtask(() {
  job3.started; // true
});

future3.then((value) {
  value; // done, after the job3 completes
});

job3.completer.complete('done');
```

You probably going to use it when you wanna limit calls for a server and stuff
like that, so since adding a timeout is a common practice (to avoid the poll to
never get free slots) you can send a duration to timeout when constructing the
worker.

```dart
FutureWorker worker = new FutureWorker(2, timeout: new Duration(seconds: 15));
```
