library future_goodies;

import 'dart:async';

typedef Future FutureFunction(item);
typedef Future FutureReduceFunction(accumulator, value);

Future sequence(Iterable iterable, FutureFunction iterator) {
  return (iterable.isEmpty) 
      ? new Future.value([])
      : pipeline([], iterable, (list, value) =>
          iterator(value).then((result) => list..add(result));
}

Future pipeline(initial, Iterable list, FutureReduceFunction iterator) {
  return (list.isEmpty) 
      ? new Future.value(null)
      : _pipeline(list.iterator, iterator, initial);
}

Future _pipeline(Iterator iterator, FutureReduceFunction async, accumulator) {
  if (iterator.moveNext()) {
    var current = iterator.current;
    return new Future.sync(() => async(accumulator, current))
                     .then((value) => _pipeline(iterator, async, value));
  } else {
    return new Future.value(accumulator);
  }
}

Future silentError(Future future) => future.catchError((_) => null);
