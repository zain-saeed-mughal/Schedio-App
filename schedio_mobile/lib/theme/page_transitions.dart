import 'package:flutter/material.dart';

import 'app_tokens.dart';

class SchedioPageTransitions extends PageTransitionsBuilder {
  const SchedioPageTransitions();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (AppMotion.reduced(context)) {
      return FadeTransition(opacity: animation, child: child);
    }
    final incoming = CurvedAnimation(
      parent: animation,
      curve: AppMotion.signature,
      reverseCurve: Curves.easeIn,
    );
    final outgoing = CurvedAnimation(
      parent: secondaryAnimation,
      curve: AppMotion.signature,
    );
    return SlideTransition(
      position: Tween(
        begin: Offset.zero,
        end: const Offset(-0.06, 0),
      ).animate(outgoing),
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0.12, 0),
          end: Offset.zero,
        ).animate(incoming),
        child: FadeTransition(opacity: incoming, child: child),
      ),
    );
  }
}
