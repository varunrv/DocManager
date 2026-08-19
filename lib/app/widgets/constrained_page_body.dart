import 'package:flutter/material.dart';

class ConstrainedPageBody extends StatelessWidget {
  const ConstrainedPageBody({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 960),
        child: child,
      ),
    );
  }
}
