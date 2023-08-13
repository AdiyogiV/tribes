import 'dart:io' as di;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:tribes/services/databaseService.dart';

class BuyItemDailog extends StatefulWidget {
  final String? house;
  final String? item;
  const BuyItemDailog({Key? key, this.house, this.item}) : super(key: key);

  @override
  _BuyItemDailogState createState() => _BuyItemDailogState();
}

class _BuyItemDailogState extends State<BuyItemDailog> {
  double padding = 15;
  double avRadius = 10;
  bool active = false;
  bool nameRequired = false;
  TextEditingController _nameController = TextEditingController();
  TextEditingController _priceController = TextEditingController();
  di.File? itemImage;
  String name = '';
  String displayPicture = '';
  File? displayPicFile;
  String price = '';
  User? user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    getItem();
  }

  getItem() async {
    DocumentSnapshot space = await DatabaseService().getItem(widget.item!);
    name = space['name'];
    displayPicture = space['image'];
    price = space['price'];
    setState(() {});
    displayPicFile =
        await DefaultCacheManager().getSingleFile(displayPicture);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(padding),
      ),
      elevation: 10,
      backgroundColor: Colors.transparent,
      child: contentBox(context),
    );
  }

  getImage() {
    return Material(
      borderRadius: BorderRadius.circular(7.0),
      elevation: 5,
      clipBehavior: Clip.antiAlias,
      child: GestureDetector(
        onTap: () {},
        child: Container(
          width: MediaQuery.of(context).size.width / 4,
          height: MediaQuery.of(context).size.width / 4,
          child: (displayPicFile != null)
              ? Image.file(
                  displayPicFile!,
                  fit: BoxFit.cover,
                )
              : Image.asset(
                  'assets/images/space.jpg',
                  fit: BoxFit.cover,
                ),
        ),
      ),
    );
  }

  contentBox(context) {
    return Container(
      padding: EdgeInsets.only(
          left: padding,
          top: avRadius + padding,
          right: padding,
          bottom: padding),
      margin: EdgeInsets.only(top: avRadius),
      decoration: BoxDecoration(
          shape: BoxShape.rectangle,
          color: Colors.white,
          borderRadius: BorderRadius.circular(avRadius),
          boxShadow: [
            BoxShadow(color: Colors.black, offset: Offset(0, 1), blurRadius: 2),
          ]),
      child: active
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  height: 20,
                ),
                Padding(padding: const EdgeInsets.all(10.0), child: getImage()),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 25,
                        fontWeight: FontWeight.w200),
                  ),
                ),
                Padding(
                    padding: const EdgeInsets.all(5.0),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Icon(
                            Icons.check_circle_outline_outlined,
                            size: 30,
                            color: CupertinoColors.activeGreen,
                          ),
                          Text(
                            'Purchase Completed',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: CupertinoColors.activeGreen,
                                fontSize: 22,
                                fontWeight: FontWeight.w300),
                          ),
                        ])),
                Text(
                  'Item will be delivered shortly to your home\nMembership token has been delivered to your tribes wallet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: CupertinoColors.activeBlue,
                      fontSize: 10,
                      fontWeight: FontWeight.w300),
                ),
                SizedBox(
                  height: 20,
                ),
                Align(
                    alignment: Alignment.center,
                    child: CupertinoButton(
                        borderRadius: BorderRadius.circular(10.0),
                        color: CupertinoColors.activeBlue,
                        onPressed: () async {
                          Navigator.of(context).pop();
                          Navigator.of(context).pop();
                        },
                        child: Column(children: [
                          Text(
                            "Go To House",
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                        ])))
              ],
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                SizedBox(
                  height: 20,
                ),
                Padding(padding: const EdgeInsets.all(10.0), child: getImage()),
                Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: Colors.black87,
                        fontSize: 25,
                        fontWeight: FontWeight.w200),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(5.0),
                  child: Text(
                    '₹ $price',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: CupertinoColors.activeBlue,
                        fontSize: 22,
                        fontWeight: FontWeight.w300),
                  ),
                ),
                SizedBox(
                  height: 20,
                ),
                Align(
                    alignment: Alignment.center,
                    child: CupertinoButton(
                        borderRadius: BorderRadius.circular(10.0),
                        color: Colors.green,
                        onPressed: () async {
                          await DatabaseService()
                              .addSpaceMember(widget.house!, user!.uid);
                          await DatabaseService()
                              .addUserItem(user!.uid, widget.item!);
                          active = true;
                          this.setState(() {});
                        },
                        child: Column(children: [
                          Text(
                            "Make Payment",
                            style: TextStyle(
                              fontSize: 20,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            "(this will be quick)",
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.white,
                            ),
                          ),
                        ])))
              ],
            ),
    );
  }
}
