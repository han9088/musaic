part of '../types.dart';

abstract class BottomSheetControllerApi {
  void close();
  void snapToIndex(int index);
  void snapToPosition(double position);
  void expand();
  void collapse();
}

abstract class BottomSheetModalController extends BottomSheetControllerApi {
  void present();
  void dismiss();
  void forceClose();
  void dismissAll();
}

