import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:adiHouse/modal/SpaceRoles.dart';

class DatabaseService {
  String uid;
  DatabaseService({this.uid});

  User user = FirebaseAuth.instance.currentUser;
  final CollectionReference userCollection =
      FirebaseFirestore.instance.collection('users');
  final CollectionReference spacesCollection =
      FirebaseFirestore.instance.collection('spaces');
  final CollectionReference nicknameCollection =
      FirebaseFirestore.instance.collection('nicknames');

  Future<bool> registerNewUser(
    String name,
    String nickname,
    String displayPicture,
  ) async {
    try {
      await nicknameCollection.doc('pairs').set({
        nickname: {'name': name, 'uid': user.uid}
      }, SetOptions(merge: true));
      FirebaseStorage storageF = FirebaseStorage.instance;
      Reference storageReference =
          storageF.ref().child('${user.uid}/displayPicture'
              '.jpg');
      await storageReference.putFile(File(displayPicture));
      storageReference.getDownloadURL().then((value) async {
        await userCollection.doc(user.uid).set({
          'name': name,
          'nickname': nickname,
          'displayPicture': value,
          "timestamp": Timestamp.fromDate(DateTime.now()),
        }, SetOptions(merge: true));
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> checkRegistration() async {
    bool newUser = true;
    await userCollection.doc(user.uid).get().then((snapshot) => {
          if (snapshot.exists) {if (snapshot['nickname'] != '') newUser = false}
        });
    return newUser;
  }

  createSpace(
    String name,
    int spaceType,
  ) async {
    var space = await FirebaseFirestore.instance.collection('spaces').add({
      'name': name,
      'spaceType': spaceType,
      'displayPicture': '',
      'description': '',
      "timestamp": Timestamp.fromDate(DateTime.now()),
    });
    String id = space.id;
    await FirebaseFirestore.instance
        .collection('userSpaces')
        .doc(user.uid)
        .collection('spaces')
        .doc(id)
        .set({
      'spaceType': spaceType,
      'role': 'owner',
      "timestamp": Timestamp.fromDate(DateTime.now()),
    });
    await FirebaseFirestore.instance
        .collection('spaceRoles')
        .doc(id)
        .collection('roles')
        .doc(user.uid)
        .set({
      'role': 'creator',
      "timestamp": Timestamp.fromDate(DateTime.now()),
    });
    return id;
  }

  createItem(
    String name,
    String price,
    String displayPicture,
    String space,
  ) async {
    CollectionReference itemCollection =
        FirebaseFirestore.instance.collection('items');
    var item = await itemCollection
        .add({'name': name, 'price': price, 'image': '', space: space});
    String id = item.id;
    FirebaseStorage storageF = FirebaseStorage.instance;
    Reference storageReference = storageF.ref().child('items/$id/displayPicture'
        '.jpg');
    await storageReference.putFile(File(displayPicture));
    storageReference.getDownloadURL().then((value) async {
      await itemCollection.doc(id).set({
        'image': value,
      }, SetOptions(merge: true));
    });
    await FirebaseFirestore.instance
        .collection('spaceItems')
        .doc(space)
        .collection('items')
        .doc(id)
        .set({
      'name': name,
      'price': price,
      "timestamp": Timestamp.fromDate(DateTime.now()),
    });

    return id;
  }

  Future<bool> isExistsSpaceMember(
    String space,
    String member,
  ) async {
    var role = await FirebaseFirestore.instance
        .collection('spaceRoles')
        .doc(space)
        .collection('roles')
        .doc(member)
        .get();
    if (role.data() != null)
      return true;
    else
      return false;
  }

  Future<bool> addSpaceMember(
    String space,
    String member,
  ) async {
    var role = 'requested';
    int spaceType = await getSpaceType(space);
    if (spaceType == 0) {
      role = 'member';
    }

    await FirebaseFirestore.instance
        .collection('spaceRoles')
        .doc(space)
        .collection('roles')
        .doc(member)
        .set({
      'role': '$role',
      "timestamp": Timestamp.fromDate(DateTime.now()),
    });
    await FirebaseFirestore.instance
        .collection('userSpaces')
        .doc(member)
        .collection('spaces')
        .doc(space)
        .set({
      'role': '$role',
      "timestamp": Timestamp.fromDate(DateTime.now()),
    }); //owner
    return true;
  }

  Future<bool> removeSpaceMember(
    String space,
    String member,
  ) async {
    var role = await FirebaseFirestore.instance
        .collection('spaceRoles')
        .doc(space)
        .collection('roles')
        .doc(member)
        .get();
    if (role.data() == null) return true; //member

    await FirebaseFirestore.instance
        .collection('spaceRoles')
        .doc(space)
        .collection('roles')
        .doc(member)
        .delete();

    await FirebaseFirestore.instance
        .collection('userSpaces')
        .doc(member)
        .collection('spaces')
        .doc(space)
        .delete();

    return true;
  }

  Future<bool> approveSpaceMember(String space, String member) async {
    try {
      var role = 'member';

      await FirebaseFirestore.instance
          .collection('spaceRoles')
          .doc(space)
          .collection('roles')
          .doc(member)
          .set({
        'role': '$role',
        "timestamp": Timestamp.fromDate(DateTime.now()),
      });
      await FirebaseFirestore.instance
          .collection('userSpaces')
          .doc(member)
          .collection('spaces')
          .doc(space)
          .set({
        'role': '$role',
        "timestamp": Timestamp.fromDate(DateTime.now()),
      });
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> rejectSpaceMember(String space, String member) async {
    try {
      await FirebaseFirestore.instance
          .collection('spaceRoles')
          .doc(space)
          .collection('roles')
          .doc(member)
          .delete();
      await FirebaseFirestore.instance
          .collection('userSpaces')
          .doc(member)
          .collection('spaces')
          .doc(space)
          .delete();
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> addUserItem(
    String usr,
    String item,
  ) async {
    var role = await FirebaseFirestore.instance
        .collection('userItems')
        .doc(user.uid)
        .collection('items')
        .doc(item)
        .get();
    if (role.data() != null) return true; //member

    await FirebaseFirestore.instance
        .collection('userItems')
        .doc(user.uid)
        .collection('items')
        .doc(item)
        .set({"timestamp": Timestamp.fromDate(DateTime.now())});
    return true;
  }

  Future<QuerySnapshot> getSpaceFollower(
    String space,
  ) async {
    var followers = await FirebaseFirestore.instance
        .collection('spaceRoles')
        .doc(space)
        .collection('roles')
        .where('role', isEqualTo: 'follower')
        .get();

    return followers;
  }

  Future<DocumentSnapshot> getPost(String post) async {
    return await FirebaseFirestore.instance.collection('posts').doc(post).get();
  }

  Future<DocumentSnapshot> getSpace(String space) async {
    return await FirebaseFirestore.instance
        .collection('spaces')
        .doc(space)
        .get();
  }

  Future<int> getSpaceType(String space) async {
    DocumentSnapshot snap = await getSpace(space);
    return snap['spaceType'];
  }

  Future<DocumentSnapshot> getItem(String item) async {
    return await FirebaseFirestore.instance.collection('items').doc(item).get();
  }

  Future<String> getPostSpace(String post) async {
    DocumentSnapshot postDoc = await getPost(post);
    return postDoc['space'];
  }

  Future<bool> isUserSpaceOwner(String space) async {
    String role = await getSpaceRole(space);
    if (role == 'owner' || role == 'creator') {
      print(role);
      return true;
    }
    print(role);
    return false;
  }

  Future<bool> isMember(
    String space,
  ) async {
    String role = await getSpaceRole(space);
    print(role);
    if (role == 'member' ||
        role == 'admin' ||
        role == 'creator' ||
        role == 'owner') {
      return true;
    }
    return false;
  }

  Future<bool> checkSpaceFeedPostingPermissions(String space) async {
    String role = await getSpaceRole(space);
    if (role == 'member' || role == 'owner' || role == 'creator') {
      return true;
    }
    return false;
  }

  Future<String> getSpaceRole(String space) async {
    DocumentSnapshot spaceRoleDoc = await FirebaseFirestore.instance
        .collection('spaceRoles')
        .doc(space)
        .collection('roles')
        .doc(user.uid)
        .get();
    if (spaceRoleDoc.data() == null) return roles.none.toString();
    return spaceRoleDoc['role'];
  }

  Future<QuerySnapshot> getSpaces(String search) async {
    if (search.isEmpty) {
      return await FirebaseFirestore.instance.collection('spaces').get();
    } else {
      return await FirebaseFirestore.instance
          .collection('spaces')
          .where('name', isGreaterThanOrEqualTo: search)
          .get();
    }
  }

  Future<QuerySnapshot> getAllSpaceRoles(String space) async {
    QuerySnapshot spaceRoleDoc = await FirebaseFirestore.instance
        .collection('spaceRoles')
        .doc(space)
        .collection('roles')
        .get();
    return spaceRoleDoc;
  }

  Future<bool> addSpacePost(
      String space,
      String videoPath,
      String thumbnailPath,
      String title,
      String replyTo,
      bool addToSpaceFeed) async {
    try {
      String video;
      String thumbnail;
      String fetchedSpace = space;
      String replyToUid;
      if (replyTo != null) {
        DocumentSnapshot replyDoc = await getPost(replyTo);
        fetchedSpace = replyDoc['space'];
        replyToUid = replyDoc['author'];
      }
      print(fetchedSpace);

      DocumentReference postDoc =
          await FirebaseFirestore.instance.collection('posts').add(
        {
          "space": fetchedSpace,
          "author": user.uid,
          "title": title,
          "replyTo": replyTo,
          "timestamp": Timestamp.fromDate(DateTime.now()),
        },
      );

      String post = postDoc.id;
      FirebaseStorage storage = FirebaseStorage.instance;

      Reference thumbnailRef = storage.ref().child('$post/thumbnail.jpg');
      Reference videoRef = storage.ref().child('$post/video.mp4');

      await thumbnailRef.putFile(File(thumbnailPath));
      thumbnail = await thumbnailRef.getDownloadURL();

      await videoRef.putFile(File(videoPath));
      video = await videoRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('posts').doc(post).set({
        "thumbnail": thumbnail,
        "video": video,
      }, SetOptions(merge: true));

      if (replyTo == null || addToSpaceFeed == true) {
        if (fetchedSpace == null) fetchedSpace = user.uid;
        await FirebaseFirestore.instance
            .collection('spacePosts')
            .doc(fetchedSpace)
            .collection("posts")
            .doc(post)
            .set(
          {
            "author": user.uid,
            "title": title,
            "thumbnail": thumbnail,
            "replyTo": replyTo,
            "video": video,
            "timestamp": Timestamp.fromDate(DateTime.now())
          },
        );
        await FirebaseFirestore.instance
            .collection('spacePosts')
            .doc(fetchedSpace)
            .set(
          {"updated": Timestamp.fromDate(DateTime.now())},
        );
      }

      if (replyTo != null) {
        await FirebaseFirestore.instance
            .collection('postReplies')
            .doc(replyTo)
            .collection("replies")
            .doc(post)
            .set(
          {
            "space": fetchedSpace,
            "author": user.uid,
            "title": title,
            "video": video,
            "thumbnail": thumbnail,
            "timestamp": Timestamp.fromDate(DateTime.now())
          },
        );
        await FirebaseFirestore.instance
            .collection('userReplies')
            .doc(replyToUid)
            .collection("replies")
            .doc(post)
            .set(
          {
            "space": fetchedSpace,
            "author": user.uid,
            "title": title,
            "video": video,
            "thumbnail": thumbnail,
            "seen": false,
            "timestamp": Timestamp.fromDate(DateTime.now())
          },
        );
      }
    } catch (e) {
      print(e);
      return false;
    }

    return true;
  }

  deleteSpacePost(String post) async {
    DocumentSnapshot postDoc =
        await FirebaseFirestore.instance.collection('posts').doc(post).get();
    var replyTo = postDoc['replyTo'];
    String space = postDoc['space'];
    String replyToUid;

    if (replyTo != null) {
      DocumentSnapshot replyToDoc = await FirebaseFirestore.instance
          .collection('posts')
          .doc(replyTo)
          .get();
      replyToUid = replyToDoc['author'];
    }

    FirebaseStorage storage = FirebaseStorage.instance;
    Reference thumbnailRef = storage.ref().child('$post/thumbnail.jpg');
    Reference videoRef = storage.ref().child('$post/video.mp4');

    await thumbnailRef.delete();
    await videoRef.delete();

    if (replyTo != null) {
      await FirebaseFirestore.instance
          .collection('postReplies')
          .doc(replyTo)
          .collection("replies")
          .doc(post)
          .delete();

      await FirebaseFirestore.instance
          .collection('userReplies')
          .doc(replyToUid)
          .collection("replies")
          .doc(post)
          .delete();
    }

    await FirebaseFirestore.instance
        .collection('spacePosts')
        .doc(space)
        .collection("posts")
        .doc(post)
        .delete();
  }

  Future updateSpace(String space, String name, String description,
      String displayPicture, bool isPublic) async {
    if (displayPicture != null) {
      FirebaseStorage storageF = FirebaseStorage.instance;
      Reference storageReference =
          storageF.ref().child('users/${user.uid}/displayPicture'
              '.jpg');
      await storageReference.putFile(File(displayPicture));
      storageReference.getDownloadURL().then((value) async {
        return await userCollection.doc(user.uid).set({
          'name': name,
          'description': description,
          'displayPicture': value,
          'public': isPublic,
        }, SetOptions(merge: true));
      });
    } else {
      return await userCollection.doc(user.uid).set({
        'name': name,
        'description': description,
        'public': isPublic,
      }, SetOptions(merge: true));
    }
  }

  Future<bool> addFollower(String space) async {
    try {
      bool isSpacePublic = (await FirebaseFirestore.instance
              .collection('spaces')
              .doc(space)
              .get())
          .data()['public'];
      String role = 'requested';
      if (isSpacePublic) {
        role = 'follower';
      }

      await FirebaseFirestore.instance
          .collection('spaceRoles')
          .doc(space)
          .collection('roles')
          .doc(user.uid)
          .set({'role': '$role'});

      await FirebaseFirestore.instance
          .collection('userSpaces')
          .doc(user.uid)
          .collection('spaces')
          .doc(space)
          .set({'public': isSpacePublic, 'role': '$role', 'type': 'user'});
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> unfollow(String space) async {
    try {
      await FirebaseFirestore.instance
          .collection('spaceRoles')
          .doc(space)
          .collection('roles')
          .doc(user.uid)
          .delete();

      await FirebaseFirestore.instance
          .collection('userSpaces')
          .doc(user.uid)
          .collection('spaces')
          .doc(space)
          .delete();
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> approveFollower(String follower) async {
    try {
      await FirebaseFirestore.instance
          .collection('spaceRoles')
          .doc(user.uid)
          .collection('roles')
          .doc(follower)
          .set({'role': 'follower'});
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }

  Future<bool> rejectFollowRequest(String follower) async {
    try {
      await FirebaseFirestore.instance
          .collection('spaceRoles')
          .doc(user.uid)
          .collection('roles')
          .doc(follower)
          .delete();
      return true;
    } catch (e) {
      print(e);
      return false;
    }
  }
}
