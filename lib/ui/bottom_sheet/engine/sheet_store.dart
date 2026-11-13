import '../types.dart';

class BottomSheetStoreSnapshot {
  const BottomSheetStoreSnapshot({
    required this.isPresented,
    required this.presentedSheetCount,
    required this.topSheetId,
    this.topSheetController,
  });

  final bool isPresented;
  final int presentedSheetCount;
  final String? topSheetId;
  final BottomSheetControllerApi? topSheetController;

  static const empty = BottomSheetStoreSnapshot(
    isPresented: false,
    presentedSheetCount: 0,
    topSheetId: null,
  );
}

/// External store for sheet snapshot — host content can subscribe without
/// rebuilding on every present when using selective listeners.
class BottomSheetSheetStore {
  BottomSheetStoreSnapshot _snapshot = BottomSheetStoreSnapshot.empty;
  final List<void Function()> _listeners = [];

  BottomSheetStoreSnapshot get snapshot => _snapshot;

  void setSnapshot(BottomSheetStoreSnapshot next) {
    _snapshot = next;
    for (final listener in List.of(_listeners)) {
      listener();
    }
  }

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);
}
