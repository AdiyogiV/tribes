import 'dart:io' as di;
import 'package:tribes/pages/houseMarket.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:tribes/services/databaseService.dart';

class JoinHouseDailog extends StatefulWidget {
  final String? space;
  const JoinHouseDailog({Key? key, this.space}) : super(key: key);

  @override
  _JoinHouseDailogState createState() => _JoinHouseDailogState();
}

class _JoinHouseDailogState extends State<JoinHouseDailog> {
  double padding = 15;
  double avRadius = 10;
  bool active = false;
  bool nameRequired = false;
  TextEditingController _nameController = TextEditingController();
  TextEditingController _priceController = TextEditingController();
  di.File? itemImage;
  String? name;
  String? displayPicture;
  File? displayPicFile;
  @override
  void initState() {
    super.initState();
    getSpaceBox();
  }

  getSpaceBox() async {
    DocumentSnapshot space = await DatabaseService().getSpace(widget.space!);
    name = space['name'];
    displayPicture = space['displayPicture'];
    setState(() {});
    displayPicFile =
        await DefaultCacheManager().getSingleFile(displayPicture!);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SizedBox(
            height: 20,
          ),
          Padding(
            padding: const EdgeInsets.all(10.0),
            child: Material(
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
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Text(
              "You require atleast one token from the $name collection to join the house",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.black87,
                  fontSize: 25,
                  fontWeight: FontWeight.w200),
            ),
          ),
          SizedBox(
            height: 20,
          ),
          Align(
              alignment: Alignment.center,
              child: CupertinoButton.filled(
                borderRadius: BorderRadius.circular(10.0),
                onPressed: () {
                  Navigator.of(context, rootNavigator: true)
                      .push(CupertinoPageRoute(builder: (context) {
                    return HouseMarket(
                      house: widget.space,
                    );
                  }));
                },
                child: Text(
                  "Go To Market",
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                  ),
                ),
              )),
        ],
      ),
    );
  }
}
