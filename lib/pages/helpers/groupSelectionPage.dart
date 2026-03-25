import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/utils/media_type_selector.dart';
import 'package:aurogram/widgets/previewBoxes/gramPreviewBox.dart';
import 'package:aurogram/widgets/ui/skeleton_widgets.dart';
import 'package:flutter/cupertino.dart';

class GroupSelectionPage extends StatefulWidget {
  const GroupSelectionPage({Key? key}) : super(key: key);

  @override
  GroupSelectionPageState createState() => GroupSelectionPageState();
}

class GroupSelectionPageState extends State<GroupSelectionPage> {
  User? _user;
  late CollectionReference _userSpacesCollection;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    _userSpacesCollection = FirebaseFirestore.instance.collection('userSpaces');
  }

  @override
  Widget build(BuildContext context) {
    if (_user == null) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: Text('Select group to post'),
        ),
        child: SafeArea(
          child: Center(child: Text('User not logged in')),
        ),
      );
    }

    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: Text('Select group to post in'),
      ),
      child: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: _userSpacesCollection
              .doc(_user!.uid)
              .collection('spaces')
              .where('role',
                  whereIn: ['member', 'owner', 'creator']).snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 10),
                itemCount: 5,
                itemBuilder: (_, __) => const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: SkeletonListItem(height: 64),
                ),
              );
            }

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return Center(
                  child: Text(
                'No grams found\n\n Join a gram or create a new one.',
                textAlign: TextAlign.center,
              ));
            }

            return ListView.builder(
              padding: EdgeInsets.symmetric(
                  vertical: 10), // Add space above the first tile

              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                DocumentSnapshot doc = snapshot.data!.docs[index];
                return GestureDetector(
                  onTap: () {
                    MediaTypeSelector.showMediaTypeSelection(
                      context: context,
                      space: doc.id,
                    );
                  },
                  child: GramPreviewBox(
                    gram: doc.id,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
