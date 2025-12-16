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

  /// Shows the dialog.
  /// Returns [true] if confirmed/OK, [false] if cancelled/dismissed (should not happen if barrierDismissible is false).
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
      barrierDismissible: false, // Must tap button
      barrierLabel: 'Dialog',
      barrierColor: Colors.black54, // Modal effect
      pageBuilder: (context, anim1, anim2) {
        return CustomAppDialog(
          title: title,
          message: message,
          type: type,
          onConfirm: onConfirm,
          confirmText: confirmText,
          cancelText: cancelText,
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(anim1.value),
          child: Opacity(opacity: anim1.value, child: child),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
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
        return Colors.red;
      case DialogType.success:
        return Colors.green;
      case DialogType.warning:
        return Colors.amber.shade700;
      case DialogType.info:
        return Colors.blue;
      case DialogType.confirmation:
        return Colors.blueAccent;
    }
  }

  IconData get _icon {
    switch (type) {
      case DialogType.error:
        return Icons.error_outline_rounded;
      case DialogType.success:
        return Icons.check_circle_outline_rounded;
      case DialogType.warning:
        return Icons.warning_amber_rounded;
      case DialogType.info:
        return Icons.info_outline_rounded;
      case DialogType.confirmation:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        width: 400, // Fixed width for desktop consistency
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(16),
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
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),

            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                color: Colors.black54,
                height: 1.4,
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        cancelText,
                        style: TextStyle(color: Colors.grey.shade700),
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
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
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
