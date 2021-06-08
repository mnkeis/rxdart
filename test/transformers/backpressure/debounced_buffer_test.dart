import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';

Stream<int> _getStream() {
  final controller = StreamController<int>();

  Timer(const Duration(milliseconds: 100), () => controller.add(1));
  Timer(const Duration(milliseconds: 200), () => controller.add(2));
  Timer(const Duration(milliseconds: 300), () => controller.add(3));
  Timer(const Duration(milliseconds: 400), () {
    controller.add(4);
    controller.close();
  });

  return controller.stream;
}

void main() {
  test('Rx.debouncedBuffer', () async {
    await expectLater(
        _getStream().debouncedBuffer((_) => Stream<void>.fromFuture(
            Future<void>.delayed(const Duration(milliseconds: 200)))),
        emitsInOrder(<dynamic>[
          [1, 2, 3, 4],
          emitsDone
        ]));
  });

  test('Rx.debouncedBuffer.dynamicWindow', () async {
    // Given the input [1, 2, 3, 4]
    // debounce 200ms on [1, 2, 3]
    // debounce 0ms on [4]
    // yields [[1, 2, 3], [4], done]
    await expectLater(
        _getStream().debouncedBuffer((value) => value == 3
            ? Stream<bool>.value(true)
            : Stream<void>.fromFuture(
                Future<void>.delayed(const Duration(milliseconds: 200)))),
        emitsInOrder(<dynamic>[
          [1, 2, 3],
          [4],
          emitsDone
        ]));
  });

  test('Rx.debouncedBuffer.reusable', () async {
    final transformer = DebouncedBufferStreamTransformer<int>(
        (_) => Stream<void>.periodic(const Duration(milliseconds: 200)));

    await expectLater(
        _getStream().transform(transformer),
        emitsInOrder(<dynamic>[
          [1, 2, 3, 4],
          emitsDone
        ]));

    await expectLater(
        _getStream().transform(transformer),
        emitsInOrder(<dynamic>[
          [1, 2, 3, 4],
          emitsDone
        ]));
  });

  test('Rx.debouncedBuffer.asBroadcastStream', () async {
    final future = _getStream()
        .asBroadcastStream()
        .debouncedBuffer((_) => Stream<void>.fromFuture(
            Future<void>.delayed(const Duration(milliseconds: 200))))
        .drain<void>();

    await expectLater(future, completes);
    await expectLater(future, completes);
  });

  test('Rx.debouncedBuffer.error.shouldThrowA', () async {
    await expectLater(
        Stream<void>.error(Exception()).debouncedBuffer((_) =>
            Stream<void>.fromFuture(
                Future<void>.delayed(const Duration(milliseconds: 200)))),
        emitsError(isException));
  });

  test('Rx.debouncedBuffer.pause.resume', () async {
    final controller = StreamController<Iterable<int>>();
    late StreamSubscription<Iterable<int>> subscription;

    subscription = Stream.fromIterable([1, 2, 3])
        .debouncedBuffer((_) => Stream<void>.fromFuture(
            Future<void>.delayed(const Duration(milliseconds: 200))))
        .listen(controller.add, onDone: () {
      controller.close();
      subscription.cancel();
    });

    subscription.pause(Future<void>.delayed(const Duration(milliseconds: 50)));

    await expectLater(
        controller.stream,
        emitsInOrder(<dynamic>[
          [1, 2, 3],
          emitsDone
        ]));
  });

  test('Rx.debouncedBuffer.emits.buffered.items.immediately', () async {
    final emissions = <Iterable<int>>[];
    final stopwatch = Stopwatch();
    final stream = Stream.fromIterable(const [1, 2, 3]).debouncedBuffer((_) =>
        Stream<void>.fromFuture(
            Future<void>.delayed(const Duration(milliseconds: 200))));
    late StreamSubscription<Iterable<int>> subscription;

    stopwatch.start();

    subscription = stream.listen(
        expectAsync1((val) {
          emissions.add(val);
        }, count: 1), onDone: expectAsync0(() {
      stopwatch.stop();

      expect(emissions, const [
        [1, 2, 3]
      ]);

      // We debounce for 100 seconds. To ensure we aren't waiting that long to
      // emit the last item after the base stream completes, we expect the
      // last value to be emitted to be much shorter than that.
      expect(stopwatch.elapsedMilliseconds < 500, isTrue);

      subscription.cancel();
    }));
  }, timeout: Timeout(Duration(seconds: 3)));

  test(
    'Rx.debouncedBuffer.cancel.emits.nothing',
    () async {
      late StreamSubscription<Iterable<int>> subscription;
      final stream = Stream.fromIterable(const [1, 2, 3]).doOnDone(() {
        subscription.cancel();
      }).debouncedBuffer((_) => Stream<void>.fromFuture(
          Future<void>.delayed(const Duration(milliseconds: 200))));

      // We expect the onData callback to be called 0 times because the
      // subscription is cancelled when the base stream ends.
      subscription = stream.listen(expectAsync1((_) {}, count: 0));
    },
    timeout: Timeout(Duration(seconds: 3)),
  );
}
