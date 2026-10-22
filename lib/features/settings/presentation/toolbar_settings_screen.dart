import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/glass/glass_backdrop.dart';
import '../../../app/glass/glass_button.dart';
import '../../../app/glass/glass_surface.dart';
import '../../editor/domain/stroke_tool.dart';
import '../application/settings_providers.dart';
import 'widgets/settings_widgets.dart';

class ToolbarSettingsScreen extends ConsumerWidget {
  const ToolbarSettingsScreen({super.key});

  static String _label(StrokeTool tool) => switch (tool) {
    StrokeTool.pen => 'Pen',
    StrokeTool.highlighter => 'Highlighter',
    StrokeTool.eraser => 'Eraser',
    StrokeTool.select => 'Select',
    StrokeTool.line => 'Line',
    StrokeTool.rectangle => 'Rectangle',
    StrokeTool.ellipse => 'Ellipse',
    StrokeTool.triangle => 'Triangle',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final order = settings.toolbarOrder;
    final visibleCount = order
        .where((t) => !settings.hiddenTools.contains(t))
        .length;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: 60,
        leading: const SettingsBackButton(),
        title: const Text('Customize toolbar'),
        actions: [
          GlassButton(
            label: 'Reset',
            kind: GlassButtonKind.plain,
            onPressed: () => notifier.update(
              (s) => s.copyWith(
                toolbarOrder: StrokeTool.values,
                hiddenTools: const {},
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: GlassBackdrop(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(16.0, (constraints.maxWidth - 720) / 2);
            return ReorderableListView.builder(
              padding: EdgeInsets.symmetric(horizontal: side, vertical: 8),
              buildDefaultDragHandles: false,
              proxyDecorator: (child, index, animation) =>
                  Material(type: MaterialType.transparency, child: child),
              itemCount: order.length,
              onReorderItem: (oldIndex, newIndex) {
                notifier.update((s) {
                  final list = [...s.toolbarOrder];
                  list.insert(newIndex, list.removeAt(oldIndex));
                  return s.copyWith(toolbarOrder: list);
                });
              },
              itemBuilder: (context, index) {
                final tool = order[index];
                final visible = !settings.hiddenTools.contains(tool);
                return Padding(
                  key: ValueKey(tool),
                  padding: const EdgeInsets.only(bottom: 8),
                  child: GlassSurface(
                    radius: 16,
                    child: Material(
                      type: MaterialType.transparency,
                      child: ListTile(
                        leading: ReorderableDragStartListener(
                          index: index,
                          child: const Icon(Icons.drag_handle),
                        ),
                        title: Text(_label(tool)),
                        subtitle: visible && visibleCount == 1
                            ? const Text('At least one tool must stay visible')
                            : null,
                        trailing: Switch(
                          value: visible,
                          onChanged: visible && visibleCount == 1
                              ? null
                              : (v) => notifier.update((s) {
                                  final hidden = {...s.hiddenTools};
                                  v ? hidden.remove(tool) : hidden.add(tool);
                                  return s.copyWith(hiddenTools: hidden);
                                }),
                        ),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
