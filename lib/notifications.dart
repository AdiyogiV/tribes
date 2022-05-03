import 'package:flutter/material.dart';
import 'package:yantra/modal/notification.dart';

class Notifications extends StatefulWidget {
  @override
  _NotificationsState createState() => _NotificationsState();
}

class _NotificationsState extends State<Notifications> {

  final List<ReplyNotification> messages = [];


  @override
  void initState() {
    // super.initState();
    // _firebaseMessaging.configure(
    //   onMessage: (Map<String, dynamic> message) async {
    //     print("onMessage: $message");
    //     final notification = message['notification'];
    //     setState(() {
    //       messages.add(ReplyNotification(
    //           ogid: notification['ogid'], reid: notification['reid']));
    //     });
    //   },
    //   onLaunch: (Map<String, dynamic> message) async {
    //     print("onLaunch: $message");

    //     final notification = message['data'];
    //     setState(() {
    //       messages.add(ReplyNotification(
    //           ogid: notification['ogid'],
    //           reid: notification['reid']
    //       ));
    //     });
    //   },
    //   onResume: (Map<String, dynamic> message) async {
    //     print("onResume: $message");
    //     final notification = message['data'];
    //     setState(() {
    //       messages.add(ReplyNotification(
    //           ogid: notification['ogid'],
    //           reid: notification['reid']
    //       ));
    //     });
    //   },
    // );
    // _firebaseMessaging.requestNotificationPermissions(
    //     const IosNotificationSettings(sound: true, badge: true, alert: true));
  }

  @override
  Widget build(BuildContext context) => ListView(
    children: messages.map(buildMessage).toList(),
  );

  Widget buildMessage(ReplyNotification message) => ListTile(
    title: Text(message.ogid),
    subtitle: Text(message.reid),
  );
}
