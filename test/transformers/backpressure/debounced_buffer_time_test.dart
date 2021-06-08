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
  test('Rx.debouncedBufferTime', () async {
    await expectLater(
        _getStream().debouncedBufferTime(const Duration(milliseconds: 200)),
        emitsInOrder(<dynamic>[
          [1, 2, 3, 4],
          emitsDone
        ]));
  });

  test('Rx.debouncedBufferTime.reusable', () async {
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

  test('Rx.debounceTime.asBroadcastStream', () async {
    final future = _getStream()
        .asBroadcastStream()
        .debouncedBufferTime(const Duration(milliseconds: 200))
        .drain<void>();

    await expectLater(future, completes);
    await expectLater(future, completes);
  });

  test('Rx.debounceTime.error.shouldThrowA', () async {
    await expectLater(
        Stream<void>.error(Exception())
            .debouncedBufferTime(const Duration(milliseconds: 200)),
        emitsError(isException));
  });

  test('Rx.debounceTime.pause.resume', () async {
    final controller = StreamController<Iterable<int>>();
    late StreamSubscription<Iterable<int>> subscription;

    subscription = Stream.fromIterable([1, 2, 3])
        .debouncedBufferTime(Duration(milliseconds: 100))
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

  test('Rx.debounceTime.emits.last.item.immediately', () async {
    final emissions = <Iterable<int>>[];
    final stopwatch = Stopwatch();
    final stream = Stream.fromIterable(const [1, 2, 3])
        .debouncedBufferTime(Duration(seconds: 100));
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
    'Rx.debounceTime.cancel.emits.nothing',
    () async {
      late StreamSubscription<Iterable<int>> subscription;
      final stream = Stream.fromIterable(const [1, 2, 3]).doOnDone(() {
        subscription.cancel();
      }).debouncedBufferTime(Duration(seconds: 10));

      // We expect the onData callback to be called 0 times because the
      // subscription is cancelled when the base stream ends.
      subscription = stream.listen(expectAsync1((_) {}, count: 0));
    },
    timeout: Timeout(Duration(seconds: 3)),
  );
}
