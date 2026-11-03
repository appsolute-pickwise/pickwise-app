import 'package:flutter/foundation.dart';

class AppNavigationController extends ChangeNotifier {
  int _index = 0;

  int get index => _index;

  void select(int index) {
    if (index < 0 || index > 2 || _index == index) return;
    _index = index;
    notifyListeners();
  }
}
