import 'package:flutter/material.dart';

class SelectionActionBar extends StatelessWidget {
  const SelectionActionBar({
    super.key,
    required this.onCopy,
    required this.onDuplicate,
    required this.onDelete,
    this.onPaste,
  });

  static const double buttonSize = 44;
  static const double pad = 6;
  static const double height = buttonSize + pad * 2;

  static double widthFor({required bool paste}) =>
      buttonSize * (paste ? 4 : 3) + pad * 2;

  final VoidCallback onCopy;
  final VoidCallback onDuplicate;
  final VoidCallback onDelete;
  final VoidCallback? onPaste;

  Widget _btn(IconData icon, String tip, VoidCallback onTap, {Color? color}) =>
      SizedBox(
        width: buttonSize,
        height: buttonSize,
        child: IconButton(
          tooltip: tip,
          onPressed: onTap,
          icon: Icon(icon, size: 22, color: color ?? const Color(0xFF222222)),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 6,
      shadowColor: Colors.black38,
      borderRadius: BorderRadius.circular(height / 2),
      child: Padding(
        padding: const EdgeInsets.all(pad),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _btn(Icons.content_copy_outlined, 'Copy', onCopy),
            if (onPaste != null)
              _btn(Icons.content_paste_outlined, 'Paste', onPaste!),
            _btn(Icons.file_copy_outlined, 'Duplicate', onDuplicate),
            _btn(
              Icons.delete_outline,
              'Delete',
              onDelete,
              color: const Color(0xFFDC2626),
            ),
          ],
        ),
      ),
    );
  }
}
