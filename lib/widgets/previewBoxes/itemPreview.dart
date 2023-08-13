import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/file.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ItemPreview extends StatefulWidget {
  final String? item;
  const ItemPreview({this.item, Key? key}) : super(key: key);

  @override
  State<ItemPreview> createState() => _ItemPreviewState();
}

class _ItemPreviewState extends State<ItemPreview> {
  String itemName = '';
  File? itemImage;
  String price = '';

  final CollectionReference itemsCollection =
      FirebaseFirestore.instance.collection('items');
  @override
  void initState() { 
    super.initState();
    initializePreview();
  }

       
 
 initializePreview() async {
    DocumentSnapshot itemdocuments =
        await itemsCollection.doc(widget.item).get();
    itemName = itemdocuments['name'];
    price = itemdocuments['price'];
    if (this.mounted) {
      setState(() {});
    }
    if (itemdocuments['image'] != '') {
      itemImage =
          await DefaultCacheManager().getSingleFile(itemdocuments['image']);
      if (this.mounted) {
        setState(() {});
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
        borderRadius: BorderRadius.circular(7.0),
        child: Material(
          elevation: 1,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              child: AspectRatio(
                aspectRatio: 1,
                child: (itemImage != null)
                    ? Image.file(
                        itemImage!,
                        fit: BoxFit.cover,
                      )
                    : Image.asset(
                        'assets/images/noise.gif',
                        fit: BoxFit.cover,
                      ),
              ),
            ),
            SizedBox(
              height: 6,
            ),
            Container(
              padding: EdgeInsets.all(4),
              child: Text(
                itemName,
                textAlign: TextAlign.left,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.all(4),
              child: Text(
                "Rs " + price,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.green),
              ),
            ),
            Container(
              padding: EdgeInsets.all(4),
              child: const Text(
                'Buy',
                style: TextStyle(
                    color: CupertinoColors.activeBlue,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(
              height: 6,
            ),
          ]),
        ));
  }
}
