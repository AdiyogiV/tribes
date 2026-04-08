import 'package:flutter/material.dart';
import 'package:aurogram/shared/presentation/widgets/universal/transparent_toolbox.dart';

class MessagesSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSearchChanged;
  final String hintText;

  const MessagesSearchBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSearchChanged,
    this.hintText = 'Search chats and users',
  });

  @override
  Widget build(BuildContext context) {
    return TransparentToolbox.search(
      searchController: controller,
      focusNode: focusNode,
      onSearchChanged: onSearchChanged,
      hintText: hintText,
    );
  }
}
