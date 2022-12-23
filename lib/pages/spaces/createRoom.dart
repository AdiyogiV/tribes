// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:drag_select_grid_view/drag_select_grid_view.dart';
// import 'package:flutter/cupertino.dart';
// import 'package:flutter/material.dart';
// import 'package:adiHouse/services/databaseService.dart';
// import 'package:adiHouse/widgets/selectableItem.dart';
//
// class CreateRoom extends StatefulWidget {
//
//   final String rid;
//   CreateRoom({this.rid});
//   @override
//   _CreateRoomState createState() => _CreateRoomState();
// }
//
// class _CreateRoomState extends State<CreateRoom> {
//   final controller = DragSelectGridViewController();
//   final CollectionReference userCollection =
//       FirebaseFirestore.instance.collection('users');
//   List<UserFrame> userList = [];
//   List<String> roomMembers = [];
//
//   @override
//   void initState() {
//     super.initState();
//     controller.addListener(scheduleRebuild);
//     getUsers();
//   }
//
//   @override
//   void dispose() {
//     controller.removeListener(scheduleRebuild);
//     super.dispose();
//   }
//
//   getUsers() async {
//     await userCollection.limit(40).get().then((querySnapshot) async {
//       querySnapshot.docs.forEach((document) {
//         userList.add(UserFrame(document.data()['displayPicture'],
//             document.data()['name'], document.id));
//         setState(() {});
//       });
//     });
//   }
//
//   addMembers() async {
//     roomMembers.clear();
//     for (int i = 0; i < controller.value.selectedIndexes.length; i++) {
//       DatabaseService().addSpaceMember(widget.rid, userList[i].uid);
//       roomMembers.add(userList[i].uid);
//     }
//     Navigator.of(context).pop();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return CupertinoPageScaffold(
//       navigationBar: CupertinoNavigationBar(
//         middle: Text('Create Room'),
//         trailing: GestureDetector(
//           onTap: () {
//             addMembers();
//           },
//           child: Text(
//             'Add',
//             style: TextStyle(color: CupertinoTheme.of(context).primaryColor),
//           ),
//         ),
//       ),
//       child: SafeArea(
//         child: DragSelectGridView(
//           gridController: controller,
//           padding: const EdgeInsets.all(8),
//           itemCount: userList.length,
//           itemBuilder: (context, index, selected) {
//             return SelectableItem(
//               index: index,
//               selected: selected,
//               imageUrl: userList[index].imageUrl,
//               title: userList[index].username,
//             );
//           },
//           gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
//             maxCrossAxisExtent: 150,
//             crossAxisSpacing: 8,
//             mainAxisSpacing: 8,
//           ),
//         ),
//       ),
//     );
//   }
//
//   void scheduleRebuild() => setState(() {});
// }
//
// class UserFrame {
//   final String imageUrl;
//   final String username;
//   final String uid;
//   UserFrame  (this.imageUrl, this.username, this.uid);
// }
