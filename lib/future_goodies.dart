library future_goodies;

import 'dart:async';

typedef Future FutureFunction(dynamic item);
typedef Future FutureReduceFunction(dynamic accumulator, dynamic value);

Future sequence(Iterable iterable, FutureFunction iterator) {
  if (iterable.isEmpty)
    return new Future.value([]);

  return pipeline([], iterable, (list, value) {
    return iterator(value).then((result) => list..add(result));
  });
}

Future pipeline(dynamic initial, Iterable list, FutureReduceFunction iterator) {
  if (list.isEmpty)
    return new Future.value(null);

  return _pipeline(list.iterator, iterator, initial);
}

Future _pipeline(Iterator iterator, FutureReduceFunction async, dynamic accumulator) {
  if (iterator.moveNext()) {
    Object current = iterator.current;
    return new Future.sync(() => async(accumulator, current))
                     .then((value) {
                       return _pipeline(iterator, async, value);
                     });
  } else
    return new Future.value(accumulator);
}

Future silentError(Future future) {
  return future.catchError((_) => null);
}