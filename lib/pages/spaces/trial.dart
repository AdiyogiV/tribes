import 'package:flutter/material.dart';
import 'package:adiHouse/widgets/post.dart';
import 'package:adiHouse/widgets/postReplies.dart';
import 'package:adiHouse/widgets/reply.dart';

class Trial extends StatefulWidget {
  final String post;

  Trial({this.post});
  @override
  _TrialState createState() => _TrialState();
}

class _TrialState extends State<Trial> {
  List<Widget> top = [];
  List<Widget> bottom = [];
  bool ready = false;

  @override
  void initState() {
    super.initState();
    getStuff();
  }

  getStuff() {
    bottom.add(
      Post(
        post: widget.post,
      ),
    );
    bottom.add(
      PostReplies(
        post: widget.post,
      ),
    );
    top.add(
      Post(
        post: widget.post,
      ),
    );
    top.add(
      Post(
        post: widget.post,
      ),
    );
    top.add(
      Post(
        post: widget.post,
      ),
    );
    top.add(
      Post(
        post: widget.post,
      ),
    );
    top.add(
      Post(
        post: widget.post,
      ),
    );
    top.add(
      Post(
        post: widget.post,
      ),
    );

    setState(() {
      ready = true;
    });
  }

  // top.add(-top.length - 1);
  // bottom.add(bottom.length);
  @override
  Widget build(BuildContext context) {
    const Key centerKey = ValueKey('second-sliver-list');
    return Scaffold(
      body: SafeArea(
        child: ready
            ? CustomScrollView(
                center: centerKey,
                slivers: <Widget>[
                  SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        return top[index];
                      },
                      childCount: top.length,
                    ),
                  ),
                  SliverList(
                    key: centerKey,
                    delegate: SliverChildBuilderDelegate(
                      (BuildContext context, int index) {
                        return bottom[index];
                      },
                      childCount: bottom.length,
                    ),
                  ),
                ],
              )
            : Container(),
      ),
    );
  }
}
