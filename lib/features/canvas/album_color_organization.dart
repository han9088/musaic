import 'package:flutter/foundation.dart';

import '../artwork/presentation/album_color_family.dart';
import '../artwork/presentation/color_selection_debounce.dart';

class AlbumColorOrganization {
  AlbumColorOrganization(this._index, {required this.onApplied});

  final AlbumColorFamilyIndex _index;
  final VoidCallback onApplied;
  final _enabled = ValueNotifier(false);
  final _family = ValueNotifier<AlbumColorFamily?>(null);
  final _debounce = ColorSelectionDebounce();
  bool enabled = false;
  AlbumColorFamily? family;
  List<Map<String, dynamic>>? _lastCatalog;
  List<AlbumColorFamily>? _lastFamilies;
  AlbumColorFamily? _lastFilter;
  List<Map<String, dynamic>> _organized = const [];

  List<Map<String, dynamic>> organize(List<Map<String, dynamic>> albums) {
    if (!enabled) return const [];
    final families = _index.availableFamilies;
    if (!identical(_lastCatalog, albums) ||
        !identical(_lastFamilies, families) ||
        _lastFilter != family) {
      _lastCatalog = albums;
      _lastFamilies = families;
      _lastFilter = family;
      final next = _index.organize(albums, family);
      if (!listEquals(_organized, next)) _organized = next;
    }
    return _organized;
  }

  ValueListenable<bool> get enabledSelection => _enabled;
  ValueListenable<AlbumColorFamily?> get familySelection => _family;

  void selectEnabled(bool value) {
    if (_enabled.value == value) return;
    _enabled.value = value;
    _debounce.schedule(_apply);
  }

  void selectFamily(AlbumColorFamily? value) {
    if (_family.value == value) return;
    _family.value = value;
    _debounce.schedule(_apply);
  }

  void retainAvailableFamilies() {
    final families = _index.availableFamilies;
    if (_family.value != null && !families.contains(_family.value)) {
      _family.value = null;
    }
    if (family != null && !families.contains(family)) family = null;
  }

  void _apply() {
    final previousFamily = family;
    retainAvailableFamilies();
    final nextEnabled = _enabled.value;
    final nextFamily = _family.value;
    final changed =
        enabled != nextEnabled || (nextEnabled && previousFamily != nextFamily);
    enabled = nextEnabled;
    family = nextFamily;
    if (!nextEnabled) {
      _lastCatalog = null;
      _lastFamilies = null;
      _lastFilter = null;
      _organized = const [];
    }
    if (changed) onApplied();
  }

  void dispose() {
    _debounce.cancel();
    _enabled.dispose();
    _family.dispose();
  }
}
