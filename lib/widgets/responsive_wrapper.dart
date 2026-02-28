import 'package:flutter/material.dart';

class ResponsiveWrapper extends StatelessWidget {
  final Widget child;
  final bool scrollable;
  final EdgeInsets padding;

  const ResponsiveWrapper({
    super.key, 
    required this.child, 
    this.scrollable = true,
    this.padding = const EdgeInsets.all(20.0),
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (scrollable) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                // THE FIX: Provide strict constraints to prevent overflow
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight,
                  maxWidth: constraints.maxWidth, 
                ),
                child: Padding(
                  padding: padding, 
                  child: child,
                ),
              ),
            );
          }
          // Non-scrollable strict layout
          return ConstrainedBox(
             constraints: BoxConstraints(
               maxHeight: constraints.maxHeight,
               maxWidth: constraints.maxWidth,
             ),
             child: Padding(padding: padding, child: child),
          );
        },
      ),
    );
  }
}