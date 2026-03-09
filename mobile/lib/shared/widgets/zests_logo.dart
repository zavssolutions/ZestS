import "package:flutter/material.dart";

class ZestsLogo extends StatelessWidget {
  const ZestsLogo({super.key, this.size = 120});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      "assets/images/zests_logo.png",
      height: size,
      width: size,
      fit: BoxFit.contain,
    );
  }
}
