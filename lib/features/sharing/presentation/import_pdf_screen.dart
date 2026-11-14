import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../../app/glass/glass_backdrop.dart';
import '../../../app/glass/glass_button.dart';
import '../../../app/glass/glass_icon_button.dart';
import '../../../app/glass/glass_list_tile.dart';
import '../../../app/glass/glass_segmented_control.dart';
import '../../../app/glass/glass_surface.dart';
import '../../../app/routes.dart';
import '../../library/application/library_providers.dart';
import '../../library/domain/notebook.dart';
import '../../library/presentation/dialogs/move_notebook_dialog.dart';
import '../application/import_service.dart';
import '../application/sharing_providers.dart';
typedef _Entry = ({String path, String name, int bytes});

class ImportPdfScreen extends ConsumerStatefulWidget {
  const ImportPdfScreen({super.key, required this.paths});

  final List<String> paths;

  @override
  ConsumerState<ImportPdfScreen> createState() => _ImportPdfScreenState();
}

class _ImportPdfScreenState extends ConsumerState<ImportPdfScreen> {
  late final ImportService _service;
  List<_Entry> _items = const [];
  bool _loading = true;
  bool _busy = false;
  bool _toFolder = false;
  String? _folderId;

  @override
  void initState() {
    super.initState();
    _service = ref.read(importServiceProvider);
    _load();
  }

  @override
  void dispose() {
    // Remove the temporary copies made by the share extension / intent.
    _service.discardSources(widget.paths);
    super.dispose();
  }

  Future<void> _load() async {
    final out = <_Entry>[];
    for (final path in widget.paths) {
      try {
        final info = await _service.inspectPdf(path);
        out.add((path: path, name: info.name, bytes: info.bytes));
      } catch (error, stack) {
        developer.log(
          'Rejected shared file',
          name: 'import',
          error: error,
          stackTrace: stack,
        );
      }
    }
    if (!mounted) return;
    setState(() {
      _items = out;
      _loading = false;
    });
  }

  void _close() =>
      context.canPop() ? context.pop() : context.go(AppRoutes.library);

  Future<void> _pickFolder() async {
    final target = await MoveNotebookDialog.show(
      context,
      currentFolderId: _folderId,
    );
    if (!mounted) return;
    if (target == null) {
      if (_folderId == null) setState(() => _toFolder = false);
      return;
    }
    setState(() {
      _folderId = target.folderId;
      _toFolder = target.folderId != null;
    });
  }

  Future<void> _import() async {
    setState(() => _busy = true);
    Notebook? first;
    try {
      for (final item in _items) {
        final nb = await _service.importPdf(item.path, folderId: _folderId);
        first ??= nb;
      }
      if (first == null) throw StateError('Nothing was imported.');
      if (!mounted) return;
      context.pushReplacement(AppRoutes.notebook(first.id));
    } catch (error, stack) {
      developer.log(
        'PDF import failed',
        name: 'import',
        error: error,
        stackTrace: stack,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('Could not import the PDF.')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static String _size(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var v = bytes.toDouble();
    var i = 0;
    while (v >= 1024 && i < units.length - 1) {
      v /= 1024;
      i++;
    }
    return '${v.toStringAsFixed(i == 0 ? 0 : 1)} ${units[i]}';
  }

  Widget _preview(_Entry e, {required double height}) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: SizedBox(
      height: height,
      child: ColoredBox(
        color: Colors.white,
        child: PdfDocumentViewBuilder.file(
          e.path,
          builder: (context, document) => document == null
              ? const Center(child: CircularProgressIndicator())
              : PdfPageView(document: document, pageNumber: 1),
        ),
      ),
    ),
  );

  Widget _body(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No readable PDF was shared.'),
            const SizedBox(height: 16),
            GlassButton(label: 'Close', onPressed: _close),
          ],
        ),
      );
    }

    final text = Theme.of(context).textTheme;
    final canImport = !_busy && !(_toFolder && _folderId == null);
    final folderName = _folderId == null
        ? null
        : ref.watch(folderProvider(_folderId!)).value?.name;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_items.length == 1) ...[
              _preview(_items.first, height: 320),
              const SizedBox(height: 12),
              Text(_items.first.name, style: text.titleMedium),
              Text(_size(_items.first.bytes), style: text.bodySmall),
            ] else
              for (final e in _items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      SizedBox(width: 64, child: _preview(e, height: 88)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              e.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall,
                            ),
                            Text(_size(e.bytes), style: text.bodySmall),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            const SizedBox(height: 20),
            Text('Destination', style: text.titleSmall),
            const SizedBox(height: 8),
            GlassSegmentedControl<bool>(
              selected: _toFolder,
              segments: const [
                GlassSegment(
                  value: false,
                  label: 'New notebook',
                  icon: Icons.note_add_outlined,
                ),
                GlassSegment(
                  value: true,
                  label: 'Existing folder',
                  icon: Icons.folder_outlined,
                ),
              ],
              onChanged: (toFolder) {
                if (toFolder) {
                  _pickFolder();
                } else {
                  setState(() {
                    _toFolder = false;
                    _folderId = null;
                  });
                }
              },
            ),
            if (_toFolder) ...[
              const SizedBox(height: 12),
              GlassSurface(
                child: Material(
                  type: MaterialType.transparency,
                  child: GlassListTile(
                    leading: Icons.folder_outlined,
                    title: folderName ?? 'Choose a folder',
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _pickFolder,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
            GlassButton(
              label: _busy ? 'Importing…' : 'Import',
              icon: Icons.file_download_outlined,
              onPressed: canImport ? _import : null,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 60,
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Center(
            child: GlassIconButton(
              tooltip: 'Cancel',
              icon: const Icon(Icons.close),
              onPressed: _busy ? null : _close,
            ),
          ),
        ),
        title: const Text('Import PDF'),
      ),
      body: GlassBackdrop(child: SafeArea(child: _body(context))),
    );
  }
}