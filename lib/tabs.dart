import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_dynamic_links/firebase_dynamic_links.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:persistent_bottom_nav_bar/persistent-tab-view.dart';
import 'package:provider/provider.dart';
import 'package:adiHouse/pages/feed.dart';
import 'package:adiHouse/pages/discovery.dart';
import 'package:adiHouse/pages/flash.dart';
import 'package:adiHouse/pages/gallery.dart';
import 'package:adiHouse/pages/initUser.dart';
import 'package:adiHouse/pages/login.dart';
import 'package:adiHouse/pages/notifications.dart';
import 'package:adiHouse/pages/replies.dart';
import 'package:adiHouse/pages/requests.dart';
import 'package:adiHouse/pages/spaces/inviteLandingPage.dart';
import 'package:adiHouse/pages/userProfile.dart';
import 'package:adiHouse/services/authService.dart';
import 'package:adiHouse/widgets/previewBoxes/userPreviewBox.dart';

class TabHandler extends StatefulWidget {
  @override
  _TabHandlerState createState() => _TabHandlerState();
}

class _TabHandlerState extends State<TabHandler> {
  final GlobalKey<NavigatorState> firstTabNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> secondTabNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> thirdTabNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> fourthTabNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> fifthTabNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> sixthTabNavKey = GlobalKey<NavigatorState>();

  PersistentTabController _controller =
      PersistentTabController(initialIndex: 0);
  User user = FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    getPermissions();
    //initDynamicLinks();
  }

  getPermissions() async {
    await Permission.camera.request().isGranted;
    await Permission.storage.request().isGranted;
    await Permission.microphone.request().isGranted;
  }

  getTabItems(String uid) {
    List<PersistentBottomNavBarItem> items = [
      PersistentBottomNavBarItem(
          activeColorPrimary: Colors.white,
          icon: Icon(
            Icons.blur_on,
          ),
          title: 'spaces'),
      PersistentBottomNavBarItem(
          activeColorPrimary: Colors.white,
          icon: Icon(
            Icons.search,
          ),
          title: 'discover'),
      PersistentBottomNavBarItem(
          activeColorPrimary: Colors.white,
          icon: Icon(
            Icons.pending,
          ),
          title: 'requests'),
      PersistentBottomNavBarItem(
          activeColorPrimary: Colors.white,
          icon: Container(
              width: 38,
              padding: EdgeInsets.all(2),
              child: UserPreview(
                uid: uid,
                showName: false,
              )),
          title: 'profile'),
    ];
    return items;
  }

  List<Widget> tripControl(Status status, int b, String userID) {
    final tabs = [
      [
        Container(child: LoginPage()),
        CupertinoTabView(
          navigatorKey: firstTabNavKey,
          builder: (context) {
            return Discovery();
          },
        ),
        Container(child: LoginPage()),
        Container(child: LoginPage()),
        Container(child: LoginPage()),
      ],
      [
        CupertinoTabView(
          navigatorKey: firstTabNavKey,
          builder: (context) {
            return Gallery();
          },
        ),
        CupertinoTabView(
          navigatorKey: secondTabNavKey,
          builder: (context) {
            return Discovery();
          },
        ),
        CupertinoTabView(
          navigatorKey: thirdTabNavKey,
          builder: (context) {
            return Notifications();
          },
        ),
        CupertinoTabView(
          navigatorKey: fourthTabNavKey,
          builder: (context) {
            return UserProfilePage(
              uid: userID,
            );
          },
        ),
      ]
    ];

    if (status == Status.Authenticated)
      return tabs[1];
    else
      return tabs[0];
  }

  GlobalKey<NavigatorState> currentNavigatorKey() {
    switch (_controller.index) {
      case 0:
        return firstTabNavKey;
        break;
      case 1:
        return secondTabNavKey;
        break;
      case 2:
        return thirdTabNavKey;
        break;
      case 3:
        return fourthTabNavKey;
        break;
      case 4:
        return fifthTabNavKey;
        break;
    }
    return null;
  }

  redirectFromLink(deepLink) {
    var res = deepLink.path.split('-');
    print(res);
    if (res[0] == '/spaceInvite') {
      Navigator.of(context, rootNavigator: true)
          .push(CupertinoPageRoute(builder: (context) {
        return InviteLandingPage(
          space: res[1],
          invitee: res[2],
        );
      }));
    }
    print(res);
    // ignore: unawaited_futures
    //Navigator.pushNamed(context, deepLink.path);
  }

  // Future<void> initDynamicLinks() async {
  //   FirebaseDynamicLinks.instance.onLink(
  //       onSuccess: (PendingDynamicLinkData dynamicLink) async {
  //     final Uri deepLink = dynamicLink?.link;

  //     if (deepLink != null) {
  //       redirectFromLink(deepLink);
  //     }
  //   }, onError: (OnLinkErrorException e) async {
  //     print('onLinkError');
  //     print(e.message);
  //   });

  //   final PendingDynamicLinkData data =
  //       await FirebaseDynamicLinks.instance.getInitialLink();
  //   final Uri deepLink = data?.link;

  //   if (deepLink != null) {
  //     redirectFromLink(deepLink);
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthService>(builder: (context, auth, child) {
      if (auth.status == Status.Unauthenticated) {
        return LoginPage();
      }
      if (auth.status == Status.Undetermined) {
        return FlashScreen();
      }
      if (auth.status == Status.Uninitialized) {
        return InitUser();
      }

      return WillPopScope(
        onWillPop: () async {
          return !await currentNavigatorKey().currentState.maybePop();
        },
        child: PersistentTabView(
          context,
          controller: _controller,
          backgroundColor: Colors.black,
          items: getTabItems(auth.userId),
          screens: tripControl(auth.status, 1, auth.userId),
          navBarStyle: NavBarStyle.style5,
          handleAndroidBackButtonPress: false,
          itemAnimationProperties: ItemAnimationProperties(
            // Navigation Bar's items animation properties.
            duration: Duration(milliseconds: 500),
            curve: Curves.ease,
          ),
        ),
      );
    });
  }
}
