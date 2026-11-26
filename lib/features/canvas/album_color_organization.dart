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
    if (changed) onApplied();
  }

  void dispose() {
    _debounce.cancel();
    _enabled.dispose();
    _family.dispose();
  }
}
