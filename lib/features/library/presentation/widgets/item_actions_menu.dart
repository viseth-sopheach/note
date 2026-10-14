import 'package:flutter/material.dart';

enum ItemAction { rename, move, delete }

/// Opens a context menu on right-click (desktop) or long-press (touch).
class ItemActionsMenu extends StatelessWidget {
  const ItemActionsMenu({
    super.key,
    required this.child,
    required this.onSelected,
    this.canMove = false,
  });

  final Widget child;
  final ValueChanged<ItemAction> onSelected;
  final bool canMove;

  Future<void> _show(BuildContext context, Offset globalPosition) async {
    final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
    final action = await showMenu<ItemAction>(
      context: context,
      position: RelativeRect.fromRect(
        globalPosition & const Size(1, 1),
        Offset.zero & overlay.size,
      ),
      items: [
        const PopupMenuItem(
          value: ItemAction.rename,
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Rename'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (canMove)
          const PopupMenuItem(
            value: ItemAction.move,
            child: ListTile(
              leading: Icon(Icons.drive_file_move_outlined),
              title: Text('Move to…'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        const PopupMenuItem(
          value: ItemAction.delete,
          child: ListTile(
            leading: Icon(Icons.delete_outline),
            title: Text('Delete'),
            contentPadding: EdgeInsets.zero,
          ),
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