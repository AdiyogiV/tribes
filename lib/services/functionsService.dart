import 'package:cloud_functions/cloud_functions.dart';

class FunctionsService {
  final HttpsCallable followToggle = FirebaseFunctions.instance.httpsCallable(
    'followToggle',
  );
  final HttpsCallable upVoteToggle = FirebaseFunctions.instance.httpsCallable(
    'upVoteToggle',
  );
  final HttpsCallable downVoteToggle = FirebaseFunctions.instance.httpsCallable(
    'downVoteToggle',
  );
  final HttpsCallable addPost = FirebaseFunctions.instance.httpsCallable(
    'addPost',
  );
  final HttpsCallable addReply = FirebaseFunctions.instance.httpsCallable(
    'addReply',
  );

  final HttpsCallable createRoom =
      FirebaseFunctions.instance.httpsCallable('createRoom');

  onFollowPressed(String targetUID) async {
    await followToggle.call(<String, String>{"targetUID": targetUID});
  }

  upVotePressed(String postUID) async {
    await upVoteToggle.call(<String, String>{"postUID": postUID});
  }

  downVotePressed(String postUID) async {
    await downVoteToggle.call(<String, String>{"postUID": postUID});
  }

  addPostDatabase(int PN, String nickname, String mainVideo, String thumbnail,
      String title, int fitOption, int progress) async {
    await addPost.call(<String, dynamic>{
      "PN": PN,
      'nickname': nickname,
      "mainVideo": mainVideo,
      "thumbnail": thumbnail,
      "title": title,
      "fitOption": fitOption,
      "progress": progress,
    });
  }

  addReplyDatabase(int PN, String nickname, String mainVideo, String thumbnail,
      String title, int fitOption, int progress, String replyToId) async {
    await addReply.call(<String, dynamic>{
      "PN": PN,
      'nickname': nickname,
      "mainVideo": mainVideo,
      "thumbnail": thumbnail,
      "title": title,
      "fitOption": fitOption,
      "progress": progress,
      "replyToId": replyToId,
    });
  }

  createRoomDatabase(String name) async {
    dynamic res = await createRoom.call(<String, String>{"name": name});
    return res.data['_path']['segments'][1];
  }
}
