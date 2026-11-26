import 'dart:async';

class ColorSelectionDebounce {
  Timer? _timer;

  void schedule(void Function() apply) {
    cancel();
    _timer = Timer(const Duration(milliseconds: 200), () {
      _timer = null;
      apply();
    });
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
