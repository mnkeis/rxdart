import 'dart:async';

import 'package:rxdart/src/streams/timer.dart';
import 'package:rxdart/src/transformers/backpressure/backpressure.dart';

/// Transforms a [Stream] so that will only emit items from the source sequence
/// if a window has completed, without the source sequence emitting
/// another item.
///
/// This window is created after the last debounced event was emitted.
/// You can use the value of the last debounced event to determine
/// the length of the next window.
///
/// A window is open until the first window event emits.
///
/// The debounced [StreamTransformer] buffers the items emitted by the source
/// Stream into a List to avoid multiple single emitions.
///
/// ### Example
///
///     Stream.fromIterable([1, 2, 3, 4])
///       .debouncedBufferTime(Duration(seconds: 1))
///       .listen(print); // prints [1, 2, 3, 4]
class DebouncedBufferStreamTransformer<T>
    extends BackpressureStreamTransformer<T, Iterable<T>> {
  /// Constructs a [StreamTransformer] which buffers events into a [List] and
  /// emits this [List] whenever the current [window] fires.
  ///
  /// The [window] is reset whenever the [Stream] that is being transformed
  /// emits an event.
  DebouncedBufferStreamTransformer(Stream Function(T event) window)
      : super(
          WindowStrategy.everyEvent,
          window,
          onWindowEnd: (Iterable<T> queue) => queue,
          ignoreEmptyWindows: true,
        );
}

/// Extends the Stream class with the ability to debounce events in various ways
extension DebouncedBufferExtensions<T> on Stream<T> {
  /// Transforms a [Stream] so that will emit a list of items emitted from the source
  /// sequence until a [window] has completed, without the source sequence emitting
  /// another item.
  ///
  /// This [window] is created after the last debounced event was emitted.
  /// You can use the value of the last debounced event to determine
  /// the length of the next [window].
  ///
  /// A [window] is open until the first [window] event emits.
  ///
  /// debouncedBuffer buffers the items emitted by the source [Stream]
  /// that are rapidly followed by another emitted item.
  ///
  /// ### Example
  ///
  ///     Stream.fromIterable([1, 2, 3, 4])
  ///       .debounce((_) => TimerStream(true, Duration(seconds: 1)))
  ///       .listen(print); // prints [1, 2, 3, 4]
  Stream<Iterable<T>> debouncedBuffer(Stream Function(T event) window) =>
      transform(DebouncedBufferStreamTransformer<T>(window));

  /// Transforms a [Stream] so that will emit a list of items emitted from the source
  /// sequence until the time span defined by [duration] passes, without the
  /// source sequence emitting another item.
  ///
  /// This time span start after the last debounced event was emitted.
  ///
  /// debouncedBufferTime buffers the items emitted by the source [Stream] that are
  /// rapidly followed by another emitted item.
  ///
  /// ### Example
  ///
  ///     Stream.fromIterable([1, 2, 3, 4])
  ///       .debounceTime(Duration(seconds: 1))
  ///       .listen(print); // prints [1, 2, 3, 4]
  Stream<Iterable<T>> debouncedBufferTime(Duration duration) =>
      transform(DebouncedBufferStreamTransformer<T>(
          (_) => TimerStream<void>(null, duration)));
}
