// 文件职责：专辑封面来源解析、图片解码、缓存及 Xerox 处理。

import 'package:flutter/widgets.dart';

import 'xerox_job_scheduler.dart';
import 'xerox_raster_cache.dart';
import 'xerox_raster_request.dart';

/// 封装或定义Xerox模式控制器相关类型与行为，负责专辑封面来源解析、图片解码、缓存及 Xerox 处理。
class XeroxModeController {
  XeroxModeController({XeroxJobScheduler? scheduler})
    : scheduler = scheduler ?? XeroxJobScheduler();

  final XeroxJobScheduler scheduler;
  final _preparedLeases = <XeroxRasterLease>[];

  bool enabled = false;
  bool preparing = false;

  /// 控制流程的开始、暂停、取消或结束，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void beginPreparation() => preparing = true;

  /// 控制流程的开始、暂停、取消或结束，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void endPreparation() => preparing = false;

  /// 准备并调度后续任务，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
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

  /// 准备并调度后续任务，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
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

  /// 应用选择并更新对应状态，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void commit(bool value) {
    enabled = value;
    preparing = false;
  }

  /// 控制流程的开始、暂停、取消或结束，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void finishTransition() {
    preparing = false;
    _releasePrepared();
  }

  /// 判断当前状态是否满足指定条件，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void cancelPreparation() {
    preparing = false;
    _releasePrepared();
  }

  /// 管理资源的获取、持有与释放，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void _releasePrepared() {
    for (final lease in _preparedLeases) {
      lease.release();
    }
    _preparedLeases.clear();
  }

  /// 释放控制器、订阅、动画及其他持有资源，用于专辑封面来源解析、图片解码、缓存及 Xerox 处理。
  void dispose() {
    _releasePrepared();
  }
}
