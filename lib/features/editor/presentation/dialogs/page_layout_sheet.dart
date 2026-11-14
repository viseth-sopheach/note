import 'package:flutter/material.dart';

import '../../../../app/glass/glass_dialog.dart';
import '../../../../app/glass/glass_list_tile.dart';
import '../../domain/page_layout.dart';

typedef LayoutChoice = ({PageLayout? layout, bool dualDocument});

Future<LayoutChoice?> showPageLayoutSheet(
  BuildContext context, {
  required PageLayout current,
}) {
  return showGlassSheet<LayoutChoice>(
    context: context,
    builder: (sheet) => Material(
      type: MaterialType.transparency,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final l in PageLayout.values)
              GlassListTile(
                leading: l == PageLayout.single
                    ? Icons.crop_portrait
                    : Icons.chrome_reader_mode_outlined,
                title: l.label,
                subtitle: l.hint,
                trailing: l == current
                    ? Icon(
                        Icons.check,
                        color: Theme.of(sheet).colorScheme.primary,
                      )
                    : null,
                onTap: () => Navigator.of(sheet).pop((
                  layout: l,
                  dualDocument: false,
                )),
              ),
            GlassListTile(
              leading: Icons.vertical_split_outlined,
              title: 'Dual document view',
              subtitle: 'Two notebooks side by side',
              onTap: () => Navigator.of(sheet).pop((
                layout: null,
                dualDocument: true,
              )),
            ),
          ],
        ),
      ),
    ),
  );
}