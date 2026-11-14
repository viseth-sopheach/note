import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/glass/glass_button.dart';
import '../../../app/glass/glass_dialog.dart';
import '../../../app/glass/glass_theme.dart';
import '../../library/application/library_providers.dart';
import 'editor_screen.dart';

/// Two notebooks side by side (wide screens) or stacked (narrow screens).
class DualDocumentScreen extends StatelessWidget {
  const DualDocumentScreen({
    super.key,
    required this.firstId,
    required this.secondId,
  });

  final String firstId;
  final String secondId;

  @override
  Widget build(BuildContext context) {
    if (firstId == secondId) return EditorScreen(notebookId: firstId);
    return LayoutBuilder(
      builder: (context, box) {
        final wide = box.maxWidth >= 900;
        final divider = SizedBox(
          width: wide ? 1 : null,
          height: wide ? null : 1,
          child: ColoredBox(color: context.glass.border),
        );
        return Flex(
          direction: wide ? Axis.horizontal : Axis.vertical,
          children: [
            Expanded(
              child: EditorScreen(key: ValueKey(firstId), notebookId: firstId),
            ),
            divider,
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: !wide,
                removeLeft: wide,
                child: EditorScreen(
                  key: ValueKey(secondId),
                  notebookId: secondId,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class DualDocumentPicker extends ConsumerWidget {
  const DualDocumentPicker({super.key, required this.excludeId});

  final String excludeId;

  static Future<String?> show(
    BuildContext context, {
    required String excludeId,
  }) => showGlassDialog<String>(
    context: context,
    builder: (_) => DualDocumentPicker(excludeId: excludeId),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allNotebooksProvider);
    return GlassDialog(
      title: const Text('Open side by side with'),
      content: SizedBox(
        width: 360,
        child: all.when(
          data: (list) {
            final items = [
              for (final n in list)
                if (n.id != excludeId) n,
            ];
            if (items.isEmpty) return const Text('No other notebooks.');
            return ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 400),
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final n in items)
                    ListTile(
                      leading: Icon(
                        n.pdfPath != null
                            ? Icons.picture_as_pdf_outlined
                            : Icons.menu_book_outlined,
                      ),
                      title: Text(
                        n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: () => Navigator.of(context).pop(n.id),
                    ),
                ],
              ),
            );
          },
          loading: () => const SizedBox(
            height: 96,
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, s) => const Text('Could not load notebooks.'),
        ),
      ),
      actions: [
        GlassButton(
          label: 'Cancel',
          kind: GlassButtonKind.plain,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
