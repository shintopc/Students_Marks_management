import 'dart:ui';
import 'package:flutter/material.dart';

enum DialogType { error, success, warning, info, confirmation }

class CustomAppDialog extends StatelessWidget {
  final String title;
  final String message;
  final DialogType type;
  final VoidCallback? onConfirm;
  final String confirmText;
  final String cancelText;

  const CustomAppDialog({
    super.key,
    required this.title,
    required this.message,
    required this.type,
    this.onConfirm,
    this.confirmText = 'OK',
    this.cancelText = 'Cancel',
  });

  /// Shows the dialog with a blur effect.
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    required DialogType type,
    VoidCallback? onConfirm,
    String confirmText = 'OK',
    String cancelText = 'Cancel',
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Dialog',
      barrierColor: Colors.black.withOpacity(0.3), // Lighter barrier for blur
      pageBuilder: (context, anim1, anim2) {
        return Stack(
          children: [
            // Blur Effect
            BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(color: Colors.transparent),
            ),
            CustomAppDialog(
              title: title,
              message: message,
              type: type,
              onConfirm: onConfirm,
              confirmText: confirmText,
              cancelText: cancelText,
            ),
          ],
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutCubic.transform(anim1.value),
          child: Opacity(opacity: anim1.value, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 250),
    );
  }

  static Future<void> showError(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return show(
      context,
      title: title,
      message: message,
      type: DialogType.error,
    );
  }

  static Future<void> showSuccess(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return show(
      context,
      title: title,
      message: message,
      type: DialogType.success,
    );
  }

  static Future<void> showWarning(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return show(
      context,
      title: title,
      message: message,
      type: DialogType.warning,
    );
  }

  static Future<void> showInfo(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return show(context, title: title, message: message, type: DialogType.info);
  }

  static Future<bool> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    VoidCallback? onConfirm,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
  }) async {
    final result = await show(
      context,
      title: title,
      message: message,
      type: DialogType.confirmation,
      onConfirm: onConfirm,
      confirmText: confirmText,
      cancelText: cancelText,
    );
    return result ?? false;
  }

  Color get _color {
    switch (type) {
      case DialogType.error:
        return const Color(0xFFD32F2F); // Material Red 700
      case DialogType.success:
        return const Color(0xFF388E3C); // Material Green 700
      case DialogType.warning:
        return const Color(0xFFF57C00); // Material Orange 700
      case DialogType.info:
        return const Color(0xFF1976D2); // Material Blue 700
      case DialogType.confirmation:
        return const Color(0xFF2E3192); // Professional Blue
    }
  }

  IconData get _icon {
    switch (type) {
      case DialogType.error:
        return Icons.error_rounded;
      case DialogType.success:
        return Icons.check_circle_rounded;
      case DialogType.warning:
        return Icons.warning_rounded;
      case DialogType.info:
        return Icons.info_rounded;
      case DialogType.confirmation:
        return Icons.help_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      elevation: 0,
      child: Container(
        width: 420,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(_icon, size: 48, color: _color),
            ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF212121),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF757575),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),

            // Buttons
            if (type == DialogType.confirmation)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        foregroundColor: Colors.grey.shade700,
                      ),
                      child: Text(
                        cancelText,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (onConfirm != null) onConfirm!();
                        Navigator.pop(context, true);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _color,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        confirmText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _color,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    confirmText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
