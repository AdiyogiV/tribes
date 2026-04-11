import 'package:cloud_firestore/cloud_firestore.dart' show DocumentSnapshot, QuerySnapshot;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aurogram/features/spaces/domain/space_service.dart';
import 'package:aurogram/shared/presentation/widgets/media/media_type_selector.dart';
import 'package:aurogram/features/profile/presentation/widgets/preview_boxes/gram_preview_box.dart';
import 'package:aurogram/shared/presentation/widgets/loaders/skeleton_widgets.dart';
import 'package:flutter/cupertino.dart';

class GramSelectionPage extends StatefulWidget {
  const GramSelectionPage({super.key});

  @override
  GramSelectionPageState createState() => GramSelectionPageState();
}

class GramSelectionPageState extends State<GramSelectionPage> {
  User? _user;
  Stream<QuerySnapshot>? _spacesStream;

  @override
  void initState() {
    super.initState();
    _user = FirebaseAuth.instance.currentUser;
    if (_user != null) {
      _spacesStream = SpaceService().getSpacesByUserStream(
        _user!.uid,
        roles: ['member', 'owner', 'creator'],
      );
    }
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
          stream: _spacesStream,
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
