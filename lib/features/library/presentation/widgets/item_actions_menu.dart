import 'dart:io';

import 'package:flutter/material.dart';

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

  static PopupMenuItem<ItemAction> _item(
    ItemAction value,
    IconData icon,
    String label,
  ) => PopupMenuItem(
    value: value,
    child: ListTile(
      leading: Icon(icon),
      title: Text(label),
      contentPadding: EdgeInsets.zero,
    ),
  );

  Future<void> _show(BuildContext context, Offset globalPosition) async {
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final driveOk = Platform.isAndroid || Platform.isIOS || Platform.isMacOS;
    final action = await showMenu<ItemAction>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        _item(ItemAction.rename, Icons.edit_outlined, 'Rename'),
        if (canMove)
          _item(ItemAction.move, Icons.drive_file_move_outlined, 'Move to…'),
        if (canShare) ...[
          _item(ItemAction.export, Icons.ios_share, 'Export PDF / Share'),
          if (driveOk)
            _item(
              ItemAction.drive,
              Icons.cloud_upload_outlined,
              'Upload to Google Drive',
            ),
          _item(ItemAction.telegram, Icons.send_outlined, 'Send to Telegram'),
        ],
        _item(ItemAction.delete, Icons.delete_outline, 'Delete'),
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
