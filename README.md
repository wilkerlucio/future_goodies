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
  return new Future.delayed(new Duration(milliseconds: 20), () => value);
}

void main() {
  Future<List<int>> result = sequence([1, 2, 3, 4], (n) => delayed(n * 2));
  
  result.then((List<int> values) {
    print(values); // [2, 4, 6, 8]
  });
}
```

### pipeline

This function works pretty much as `sequence`, but it needs an initial accumulator and it accumulates the results, for example:

```dart
import 'package:future_goodies/future_goodies.dart';
import 'dart:async';

Future delayed(value) {
  return new Future.delayed(new Duration(milliseconds: 20), () => value);
}

void main() {
  Future<int> result = pipeline(0, [1, 2, 3, 4], (int acc, int n) => acc + n);
  
  result.then((int sum) {
    print(sum); // 10
  });
}
```

In the same fashion as `sequence`, if any iteration fail, the `Future` will fail too with the error.
