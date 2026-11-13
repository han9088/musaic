var _sheetIdCounter = 0;

String createBottomSheetId() {
  _sheetIdCounter += 1;
  return 'sheet-$_sheetIdCounter-${DateTime.now().millisecondsSinceEpoch}';
}

/// Reset counter — for tests only.
void debugResetBottomSheetIdCounter() {
  _sheetIdCounter = 0;
}
