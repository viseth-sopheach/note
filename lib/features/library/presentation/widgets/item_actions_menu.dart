import 'package:flutter/material.dart';

import '../../../../app/glass/glass_menu.dart';
import '../../../sharing/application/drive_service.dart';

enum ItemAction { rename, move, delete, export, drive, telegram }

class ItemActionsMenu extends StatelessWidget {
  const ItemActionsMenu({
    super.key,
    required this.child,
    required this.onSelected,
    this.canMove = false,
    this.canShare = false,
  });

  final Widget child;
  final ValueChanged<ItemAction> onSelected;
  final bool canMove;
  final bool canShare;

  Future<void> _show(BuildContext context, Offset globalPosition) async {
    final driveOk = DriveService.isSupported;
    final action = await showGlassMenu<ItemAction>(
      context: context,
      position: globalPosition,
      items: [
        const GlassMenuItem(
          value: ItemAction.rename,
          icon: Icons.edit_outlined,
          label: 'Rename',
        ),
        if (canMove)
          const GlassMenuItem(
            value: ItemAction.move,
            icon: Icons.drive_file_move_outlined,
            label: 'Move to…',
          ),
        if (canShare && driveOk)
          const GlassMenuItem(
            value: ItemAction.drive,
            icon: Icons.cloud_upload_outlined,
            label: 'Upload to Google Drive',
          ),
        const GlassMenuItem(
          value: ItemAction.delete,
          icon: Icons.delete_outline,
          label: 'Delete',
          destructive: true,
        ),
      ],
    );
    if (action != null) onSelected(action);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) => _show(context, details.globalPosition),
      onLongPressStart: (details) => _show(context, details.globalPosition),
      child: child,
    );
  }
}
