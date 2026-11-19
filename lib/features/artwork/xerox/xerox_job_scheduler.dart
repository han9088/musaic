import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';

import 'xerox_raster_cache.dart';
import 'xerox_raster_request.dart';

/// Prepares a finite set of artwork requests while the cache caps GPU work.
class XeroxJobScheduler {
  XeroxJobScheduler({
    this.maxConcurrentRequests = 2,
    XeroxRasterCache? cache,
  }) : cache = cache ?? XeroxRasterCache.instance {
    if (maxConcurrentRequests <= 0) {
      throw ArgumentError.value(maxConcurrentRequests, 'maxConcurrentRequests');
    }
  }

  final int maxConcurrentRequests;
  final XeroxRasterCache cache;

  Future<List<XeroxRasterLease>> prepare(
    Iterable<XeroxRasterRequest> requests, {
    bool Function()? isActive,
    bool allowFailures = false,
  }) async {
    final unique = <XeroxRasterKey, XeroxRasterRequest>{};
    for (final request in requests) {
      unique.putIfAbsent(request.key, () => request);
    }

    final values = unique.values.toList(growable: false);
    final leases = <XeroxRasterLease>[];
    final failures = <Object>[];
    var cursor = 0;
    var cancelled = false;

    Future<void> worker() async {
      while (!cancelled) {
        if (isActive != null && !isActive()) {
          cancelled = true;
          return;
        }
        if (cursor >= values.length) return;
        final request = values[cursor++];

        try {
          final lease = await cache.acquire(request);
          if (cancelled || (isActive != null && !isActive())) {
            lease.release();
            cancelled = true;
            return;
          }
          leases.add(lease);
        } catch (error, stack) {
          failures.add(error);
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stack,
              library: 'Xerox raster preparation',
            ),
          );
        }
      }
    }

    try {
      final workerCount = values.length < maxConcurrentRequests
          ? values.length
          : maxConcurrentRequests;
      await Future.wait([
        for (var i = 0; i < workerCount; i++) worker(),
      ]);
      if (cancelled || (isActive != null && !isActive())) {
        throw StateError('Xerox preparation was cancelled.');
      }
      if (failures.isNotEmpty && !allowFailures) {
        throw StateError(
          'Unable to rasterize ${failures.length} visible artwork item(s).',
        );
      }
      return leases;
    } catch (_) {
      for (final lease in leases) {
        lease.release();
      }
      rethrow;
    }
  }

  Future<void> precacheOriginals(
    Iterable<XeroxRasterRequest> requests,
    BuildContext context, {
    bool Function()? isActive,
  }) async {
    final unique = <String, XeroxRasterRequest>{};
    for (final request in requests) {
      unique.putIfAbsent(request.sourceKey, () => request);
    }
    final values = unique.values.toList(growable: false);
    for (var start = 0; start < values.length; start += maxConcurrentRequests * 2) {
      if (isActive != null && !isActive()) {
        throw StateError('Original artwork preparation was cancelled.');
      }
      final end = (start + maxConcurrentRequests * 2).clamp(0, values.length);
      await Future.wait([
        for (final request in values.sublist(start, end))
          precacheImage(
            request.image,
            context,
            size: Size.square(request.resolution.toDouble()),
            onError: (error, stack) {},
          ),
      ]);
    }
  }
}
