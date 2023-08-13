import 'package:flutter/material.dart';

@immutable
class ReplyNotification{
  final String ogid;
  final String reid;

  const ReplyNotification({
    required this.ogid,
    required this.reid
  });
}

class FollowNotification{
  final String ogid;
  final String reid;

  const FollowNotification({
    required this.ogid,
    required this.reid
  });
}