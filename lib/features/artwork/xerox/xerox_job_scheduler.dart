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

    final leases = <XeroxRasterLease>[];
    final failures = <Object>[];
    final values = unique.values.toList(growable: false);
    try {
      for (var start = 0; start < values.length; start += maxConcurrentRequests) {
        if (isActive != null && !isActive()) {
          throw StateError('Xerox preparation was cancelled.');
        }
        final end = (start + maxConcurrentRequests).clamp(0, values.length);
        final batch = values.sublist(start, end);
        final results = await Future.wait(
          batch.map((request) async {
            try {
              return await cache.acquire(request);
            } catch (error, stack) {
              failures.add(error);
              FlutterError.reportError(
                FlutterErrorDetails(
                  exception: error,
                  stack: stack,
                  library: 'Xerox raster preparation',
                ),
              );
              return null;
            }
          }),
        );
        leases.addAll(results.whereType<XeroxRasterLease>());
      }
      if (isActive != null && !isActive()) {
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
