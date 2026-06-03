import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Wrapper que centra el contenido y aplica márgenes horizontales en web ancho.
/// - App nativa / web móvil (<600 px): sin márgenes extra.
/// - Web escritorio (≥600 px): 20 % de margen a cada lado.
class AppLayoutWrapper extends StatelessWidget {
  final Widget child;

  const AppLayoutWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final double width = MediaQuery.of(context).size.width;
    final bool isWebMobile = kIsWeb && width < 600;

    final double horizontalPadding = kIsWeb
        ? (isWebMobile ? 0.0 : width * 0.20)
        : 0.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: child,
    );
  }
}
