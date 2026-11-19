import 'package:flutter/widgets.dart';

import 'xerox_job_scheduler.dart';
import 'xerox_raster_cache.dart';
import 'xerox_raster_request.dart';

/// Owns the global Original/Xerox display mode and transition-time image pins.
class XeroxModeController {
  XeroxModeController({XeroxJobScheduler? scheduler})
    : scheduler = scheduler ?? XeroxJobScheduler();

  final XeroxJobScheduler scheduler;
  final _preparedLeases = <XeroxRasterLease>[];

  bool enabled = false;
  bool preparing = false;

  void beginPreparation() => preparing = true;

  void endPreparation() => preparing = false;

  Future<void> prepareEnable(
    Iterable<XeroxRasterRequest> requests, {
    bool Function()? isActive,
  }) async {
    preparing = true;
    _releasePrepared();
    final leases = await scheduler.prepare(requests, isActive: isActive);
    if (isActive != null && !isActive()) {
      for (final lease in leases) {
        lease.release();
      }
      throw StateError('Xerox mode preparation was cancelled.');
    }
    _preparedLeases.addAll(leases);
  }

  Future<void> prepareDisable(
    Iterable<XeroxRasterRequest> requests,
    BuildContext context, {
    bool Function()? isActive,
  }) async {
    preparing = true;
    await scheduler.precacheOriginals(
      requests,
      context,
      isActive: isActive,
    );
  }

  void commit(bool value) {
    enabled = value;
    preparing = false;
  }

  void finishTransition() {
    preparing = false;
    _releasePrepared();
  }

  void cancelPreparation() {
    preparing = false;
    _releasePrepared();
  }

  void _releasePrepared() {
    for (final lease in _preparedLeases) {
      lease.release();
    }
    _preparedLeases.clear();
  }

  void dispose() {
    _releasePrepared();
  }
}
