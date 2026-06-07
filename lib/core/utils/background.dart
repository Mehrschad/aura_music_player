import 'package:flutter/foundation.dart';

/// Runs a pure top-level/static function on a background isolate via [compute],
/// keeping heavy work off the UI thread.
///
/// Per the performance budget, library scanning and tag/lyrics parsing must
/// never block the main thread. The functions passed here must be top-level or
/// static and their arguments/results sendable across isolates (the LRC parser,
/// waveform generation and tag mapping all qualify). On the web, where isolates
/// are unavailable, [compute] transparently runs inline.
Future<R> runOffMainThread<Q, R>(ComputeCallback<Q, R> fn, Q arg) =>
    compute(fn, arg);
