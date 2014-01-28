library future_goodies;

import 'dart:async';

typedef Future FutureFunction(Object item);

Future sequence(Iterable iterable, FutureFunction iterator) {
  if (iterable.isEmpty)
    return new Future.value([]);

  return _sequence(iterable.iterator, iterator, new List());
}

Future _sequence(Iterator iterator, FutureFunction async, List accumulator) {
  if (iterator.moveNext()) {
    Object current = iterator.current;
    return new Future.sync(() => async(current))
                     .then((value) {
                       accumulator.add(value);
                       return _sequence(iterator, async, accumulator);
                     });
  } else
    return new Future.value(accumulator);
}