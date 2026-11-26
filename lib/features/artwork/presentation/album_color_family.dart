// 文件职责：缓存封面主题色，并根据当前曲库实际色相分布动态归并色系。
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 由当前曲库色相聚类动态生成的色系，不预设分类枚举。
@immutable
class AlbumColorFamily {
  const AlbumColorFamily({required this.id, required this.label, required this.hue, required this.isNeutral});
  final String id;
  final String label;
  final double hue;
  final bool isNeutral;
  @override
  bool operator ==(Object other) => other is AlbumColorFamily && other.id == id;
  @override
  int get hashCode => id.hashCode;
}

/// 缓存每张封面的主题色特征；聚类只在索引批量变化后异步重算。
class AlbumColorFamilyIndex extends ChangeNotifier {
  static const _storageKey = 'artwork.album_color_features.v2';
  static const _clusterGapDegrees = 38.0;
  final Map<String, _ColorFeature> _features = {};
  Future<void> _pendingWrite = Future<void>.value();
  List<AlbumColorFamily> _families = const [];
  Map<String, AlbumColorFamily> _albumFamilies = const {};
  bool _restored = false;
  bool _rebuildScheduled = false;
  bool _writeScheduled = false;

  List<AlbumColorFamily> get availableFamilies => List.unmodifiable(_families);

  Future<void> restore() async {
    if (_restored) return;
    _restored = true;
    try {
      final raw = await SharedPreferencesAsync().getString(_storageKey);
      if (raw == null) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return;
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is List && value.length == 3 && value.every((part) => part is num)) {
          _features[entry.key] = _ColorFeature(
            hue: (value[0] as num).toDouble(),
            saturation: (value[1] as num).toDouble(),
            lightness: (value[2] as num).toDouble(),
          );
        }
      }
      _scheduleRebuild();
    } catch (error) {
      debugPrint('Could not restore album color index: $error');
    }
  }

  void register(Map<String, dynamic> album, Color accent) {
    final key = _key(album);
    final hsl = HSLColor.fromColor(accent);
    final feature = _ColorFeature(hue: hsl.hue, saturation: hsl.saturation, lightness: hsl.lightness);
    if (_features[key] == feature) return;
    _features[key] = feature;
    _scheduleRebuild();
    _scheduleWrite();
  }

  AlbumColorFamily? familyOf(Map<String, dynamic> album) => _albumFamilies[_key(album)];

  /// 清除不属于当前曲库的索引，避免不同音乐源的旧色系残留。
  void retainAlbums(List<Map<String, dynamic>> albums) {
    final keys = albums.map(_key).toSet();
    final removed = _features.keys.where((key) => !keys.contains(key)).toList();
    if (removed.isEmpty) return;
    for (final key in removed) { _features.remove(key); }
    _scheduleRebuild();
    _scheduleWrite();
  }

  List<Map<String, dynamic>> organize(List<Map<String, dynamic>> albums, AlbumColorFamily? selected) {
    final result = albums.where((album) {
      final family = familyOf(album);
      return selected == null ? family != null : family == selected;
    }).toList()
      ..sort((a, b) {
        final left = familyOf(a);
        final right = familyOf(b);
        final familyOrder = (left?.hue ?? 999).compareTo(right?.hue ?? 999);
        return familyOrder != 0 ? familyOrder : _key(a).compareTo(_key(b));
      });
    return List.unmodifiable(result);
  }

  void _scheduleRebuild() {
    if (_rebuildScheduled) return;
    _rebuildScheduled = true;
    scheduleMicrotask(() {
      _rebuildScheduled = false;
      _rebuildFamilies();
    });
  }

  void _rebuildFamilies() {
    final chromatic = <(String, _ColorFeature)>[];
    final neutral = <String>[];
    for (final entry in _features.entries) {
      final f = entry.value;
      if (f.saturation < 0.18 || f.lightness < 0.07 || f.lightness > 0.93) {
        neutral.add(entry.key);
      } else {
        chromatic.add((entry.key, f));
      }
    }
    chromatic.sort((a, b) => a.$2.hue.compareTo(b.$2.hue));
    final clusters = <List<(String, _ColorFeature)>>[];
    for (final item in chromatic) {
      if (clusters.isEmpty || item.$2.hue - clusters.last.last.$2.hue > _clusterGapDegrees) {
        clusters.add([item]);
      } else {
        clusters.last.add(item);
      }
    }
    // Hue 是环形数据：跨越 0° 的首尾色相簇需要合并。
    if (clusters.length > 1 &&
        clusters.first.first.$2.hue + 360 - clusters.last.last.$2.hue <= _clusterGapDegrees) {
      final merged = [...clusters.last, ...clusters.first];
      clusters..removeLast()..removeAt(0)..insert(0, merged);
    }

    final families = <AlbumColorFamily>[];
    final mapping = <String, AlbumColorFamily>{};
    final grouped = <String, List<(String, _ColorFeature)>>{};
    for (final cluster in clusters) {
      final hue = _circularMean(cluster.map((item) => item.$2.hue));
      grouped.putIfAbsent(_labelForHue(hue), () => []).addAll(cluster);
    }
    for (final entry in grouped.entries) {
      final hue = _circularMean(entry.value.map((item) => item.$2.hue));
      final family = AlbumColorFamily(
        id: 'family:${entry.key}',
        hue: hue,
        label: entry.key,
        isNeutral: false,
      );
      families.add(family);
      for (final item in entry.value) { mapping[item.$1] = family; }
    }
    if (neutral.isNotEmpty) {
      const family = AlbumColorFamily(id: 'neutral', label: '中性色', hue: 360, isNeutral: true);
      families.add(family);
      for (final key in neutral) { mapping[key] = family; }
    }
    final changed = !_sameFamilies(_families, families);
    _families = List.unmodifiable(families);
    _albumFamilies = Map.unmodifiable(mapping);
    if (changed) notifyListeners();
  }

  static bool _sameFamilies(List<AlbumColorFamily> a, List<AlbumColorFamily> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static double _circularMean(Iterable<double> hues) {
    var x = 0.0;
    var y = 0.0;
    for (final hue in hues) {
      final radians = hue * math.pi / 180;
      x += math.cos(radians);
      y += math.sin(radians);
    }
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// 仅为实际生成的聚类中心命名；不决定分类是否存在或聚类边界。
  static String _labelForHue(double hue) {
    if (hue < 15 || hue >= 345) return '红色';
    if (hue < 45) return '橙色';
    if (hue < 70) return '黄色';
    if (hue < 165) return '绿色';
    if (hue < 200) return '青色';
    if (hue < 255) return '蓝色';
    if (hue < 285) return '紫色';
    return '粉色';
  }

  String _key(Map<String, dynamic> album) {
    final id = album['id'] as String?;
    final asset = album['asset'] as String? ?? '';
    return jsonEncode([id ?? asset, asset, album['artworkVersion']]);
  }

  void _scheduleWrite() {
    if (_writeScheduled) return;
    _writeScheduled = true;
    scheduleMicrotask(() {
      _writeScheduled = false;
      final snapshot = jsonEncode({
        for (final entry in _features.entries)
          entry.key: [entry.value.hue, entry.value.saturation, entry.value.lightness],
      });
      _pendingWrite = _pendingWrite.then((_) async {
        try {
          await SharedPreferencesAsync().setString(_storageKey, snapshot);
        } catch (error) {
          debugPrint('Could not persist album color index: $error');
        }
      });
    });
  }
}

@immutable
class _ColorFeature {
  const _ColorFeature({required this.hue, required this.saturation, required this.lightness});
  final double hue;
  final double saturation;
  final double lightness;
  @override
  bool operator ==(Object other) => other is _ColorFeature &&
      (other.hue - hue).abs() < 0.01 &&
      (other.saturation - saturation).abs() < 0.001 &&
      (other.lightness - lightness).abs() < 0.001;
  @override
  int get hashCode => Object.hash(hue.round(), saturation, lightness);
}
