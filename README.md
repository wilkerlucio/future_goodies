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

### settle

Makes a list of futures always completes, returning the state of
the completion.

```dart
settle([new Future.value('hello'), new Future.error('err')]).then((List<SettleResult> results) {
  results[0]; // <SettleResult status:#completed result:hello>
  results[1]; // <SettleResult status:#rejected error:err>
});
```

If you wanna do it for a single future, check [SettleResult.settle]

### SettleResult.settle

Wraps a future to always completes with a SettleResult

This function will return a [Future], this future will
be an instance of [SettleResult].

Given the original future has completed with success,
the [SettleResult] will have the [status] value of
[COMPLETED] and the [result] will have the completion value.

Given the original future fails, the [SettleResult] will
have the [status] as [REJECTED] and the `error` will contain
the thrown error.

```dart
SettleResult.settle(new Future.value('ok')).then((SettleResult res) {
 res.status; // SettleResult.COMPLETED
 res.result; // 'ok'
 res.error; // null
});

SettleResult.settle(new Future.error('err')).then((SettleResult res) {
  res.status; // SettleResult.REJECTED
  res.result; // null
  res.error; // 'err'
});
```

### unfold

The methods [sequence] and [pipeline] are great ways to process asynchronous
arrays of futures and tasks. Sometimes, however, you may not know the array
in advance, or may not need or want to process all the items in the array.

For example, here are a few situations where you may not know the bounds:

1. You need to process a queue to which items are still being added as you process it
2. You need to execute a task repeatedly until a particular condition becomes true
3. You need to selectively process items in an array, rather than all items

In these cases, you can use when/unfold to iteratively (and asynchronously)
process items until a particular condition, which you supply, is true.

    Future future = unfold(unspool, stopCondition, handler, seed);

Where:
* [unspool] - function that, given a seed, returns a [valueToSendToHandler, newSeed]
pair. May return a list, list of futures, future for an list, or future for an list of futures.
* [stopCondition] - function that should return truthy when the unfold should stop
* [handler] - function that receives the valueToSendToHandler of the current
iteration. This function can process valueToSendToHandler in whatever way you need.
It may return a [Future] to delay the next iteration of the [unfold].

Send values produced by [unspool] iteratively to [handler] until a condition is
true. The [unspool] function acts like a generator, taking a [seed] and producing
a pair of [value, newSeed] (or a [Future] pair, see above). The value will be
passed to [handler], which can do any necessary on or with value, and may return
a future. The newSeed will be passed as the [seed] to the next iteration of [unspool].

## Examples

This example generates random numbers at random intervals for 10 seconds.

The condition could easily be modified (to return false;) to generate random numbers
forever. Interestingly, this would not overflow the call stack, and would not starve
application code since it is asynchronous.

```dart
Random random = new Random();

// set end time for 10 seconds from now
DateTime end = new DateTime.now().add(new Duration(seconds: 10));

// Generate random numbers at random intervals!
// Note that we could generate these forever, and never
// blow the call stack, nor would we starve the application
Function unspool = (seed) {
  // seed is passed in, although for this example, we don't need it

  // Return a random number as the value, and the time it was generated
  // as the new seed
  var next = [random.nextInt(100), new DateTime.now()];

  // Introduce a delay, just for fun, to show that we can return a future
  return new Future.delayed(new Duration(milliseconds: random.nextInt(1000)), () => next);
};

// Stop after 10 seconds
Function condition = (DateTime time) {
  return time.isAfter(end);
};

Function log = (value) {
  print(value);
};

DateTime start = new DateTime.now();

unfold(unspool, condition, log, start).then((_) {
  print('Ran for ' + new DateTime.now().difference(start).inMicroseconds.toString() + 'ms');
});
```

### unfoldList

Unfold resolving into a list

    unfoldList(unspool, stopCondition, seed);

Where:

* [unspool] - function that, given a seed, returns a [valueToAddToList, newSeed] pair.
  May return an array, array of futures, futures for an array, or future for an array of futures.
* [stopCondition] - function that should return truthy when the unfold should stop
* [seed] - intial value provided to the first [unspool] invocation. May be a [Future].

Generate a list of items from a [seed] by executing the [unspool] function while [stopCondition]
returns true. The result [Future] will fulfill with a [List] containing all each valueToAddToList
that is generated by [unspool].

```dart
Function stopCondition = (int i) => i == 3;
Function unspool = (int x) => [x, x + 1];

unfoldList(unspool, stopCondition, 0).then((List<int> values) {
  print(values); // [0, 1, 2]
});
```

The methods [unfold] and [unfoldList] ideas and a lot of documentation text was were extracted from the great
When library: https://github.com/cujojs/when/blob/master/docs/api.md#unbounded-lists
