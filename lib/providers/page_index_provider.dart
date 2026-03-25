import 'package:flutter/foundation.dart';

class PageIndexProvider extends ChangeNotifier {
  bool enableAudio = true;
  String? activePost;

  void toggleAudio() {
    enableAudio = !enableAudio;
    notifyListeners();
  }

  void setPost(String post) {
    activePost = post;
    notifyListeners();
  }

  String getPost() {
    return activePost ?? '';
  }
}
