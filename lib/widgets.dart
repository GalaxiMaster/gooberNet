
import 'package:flutter/material.dart';

class LoadingOverlay {
  final OverlayEntry _overlayEntry = OverlayEntry(
    builder: (context) => Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 255/2),
        child: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    ),
  );
  bool overlayOn = false;
  void showLoadingOverlay(BuildContext context) {
    if (overlayOn) return;
    Overlay.of(context).insert(_overlayEntry);
    overlayOn = true;
  }

  // Remove loading overlay
  void removeLoadingOverlay() {
    if (!overlayOn) return;
    _overlayEntry.remove();
    overlayOn = false;
  }
  void dispose() {
    if (overlayOn) {
      _overlayEntry.remove();
      overlayOn = false;
    }
    _overlayEntry.dispose();
  }
}