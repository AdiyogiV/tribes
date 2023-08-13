import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:persistent_bottom_nav_bar_v2/persistent-tab-view.dart';
import 'package:provider/provider.dart';
import 'package:tribes/pages/discovery.dart';
import 'package:tribes/pages/flash.dart';
import 'package:tribes/pages/gallery.dart';
import 'package:tribes/pages/initUser.dart';
import 'package:tribes/pages/login.dart';
import 'package:tribes/pages/notifications.dart';
import 'package:tribes/pages/spaces/inviteLandingPage.dart';
import 'package:tribes/pages/userProfile.dart';
import 'package:tribes/services/authService.dart';
import 'package:tribes/widgets/previewBoxes/userPreviewBox.dart';

class TabHandler extends StatefulWidget {
  @override
  _TabHandlerState createState() => _TabHandlerState();
}

class _TabHandlerState extends State<TabHandler> {
  final GlobalKey<NavigatorState> firstTabNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> secondTabNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> thirdTabNavKey = GlobalKey<NavigatorState>();
  final GlobalKey<NavigatorState> fourthTabNavKey = GlobalKey<NavigatorState>();

  PersistentTabController _controller =
      PersistentTabController(initialIndex: 0);
   User? user = FirebaseAuth.instance.currentUser;

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

  getTabItems(String? uid) {
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

  List<Widget> tripControl(Status status, String? userID) {
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

  GlobalKey<NavigatorState>? currentNavigatorKey() {
    switch (_controller.index) {
      case 0:
        return firstTabNavKey;
      case 1:
        return secondTabNavKey;
      case 2:
        return thirdTabNavKey;
      case 3:
        return fourthTabNavKey;
      default:
        return firstTabNavKey;

    }  }

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
   
      if (auth.status == Status.Uninitialized) {
        return InitUser();
      }

      return WillPopScope(
        onWillPop: () async {
          return await currentNavigatorKey()!.currentState!.maybePop();
        },
        child: PersistentTabView(
          context,
          controller: _controller,
          backgroundColor: Colors.black,
          items: getTabItems(auth.userId),
          screens: tripControl(auth.status, auth.userId),
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
