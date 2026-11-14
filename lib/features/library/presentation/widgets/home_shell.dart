import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/glass/glass_icon_button.dart';
import '../../../../app/glass/glass_menu.dart';
import '../../../../app/glass/glass_surface.dart';
import '../../../../app/routes.dart';
import '../../application/library_providers.dart';
import '../../domain/folder.dart';

abstract final class HomeColors {
  static const bg = Color(0xFF0B0D17);
  static const accent = Color(0xFF7C6CFF);
  static const accent2 = Color(0xFF3FA9F5);
  static const muted = Color(0xFF9AA0B4);
}

class HomeBackground extends StatelessWidget {
  const HomeBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: HomeColors.bg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Positioned(
            top: -120,
            left: -80,
            child: _Orb(420, HomeColors.accent.withValues(alpha: 0.35)),
          ),
          Positioned(
            bottom: -160,
            right: -100,
            child: _Orb(480, HomeColors.accent2.withValues(alpha: 0.25)),
          ),
          Positioned(
            top: 220,
            right: 220,
            child: _Orb(300, const Color(0xFFE05CC8).withValues(alpha: 0.14)),
          ),
          child,
        ],
      ),
    );
  }
}

class _Orb extends StatelessWidget {
  const _Orb(this.size, this.color);
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(
          sigmaX: 90,
          sigmaY: 90,
          tileMode: TileMode.decal,
        ),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Sidebar
// ---------------------------------------------------------------------------

class HomeSidebar extends ConsumerWidget {
  const HomeSidebar({
    super.key,
    required this.compact,
    required this.isRoot,
    this.favoritesSelected = false,
    this.afterTap,
  });

  final bool compact;
  final bool isRoot;
  final bool favoritesSelected;
  final VoidCallback? afterTap;

  void _go(VoidCallback nav) {
    afterTap?.call();
    nav();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final folders = ref.watch(foldersProvider(null)).value ?? const <Folder>[];

    return GlassSurface(
      radius: 28,
      intensity: GlassIntensity.thick,
      padding: const EdgeInsets.all(12),
      child: SizedBox(
        width: compact ? 56 : 232,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Brand(compact: compact),
            const SizedBox(height: 16),
            _NavTile(
              icon: Icons.home_rounded,
              label: 'Library',
              selected: isRoot,
              compact: compact,
              onTap: () => _go(() => context.go(AppRoutes.library)),
            ),
            _NavTile(
              icon: Icons.star_rounded,
              label: 'Favorites',
              selected: favoritesSelected,
              compact: compact,
              onTap: () => _go(() => context.go(AppRoutes.favorites)),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  if (!compact) const _SectionLabel('FOLDERS'),
                  for (final f in folders)
                    _NavTile(
                      icon: Icons.folder_outlined,
                      label: f.name,
                      selected: false,
                      compact: compact,
                      onTap: () =>
                          _go(() => context.push(AppRoutes.folder(f.id))),
                    ),
                ],
              ),
            ),
            _NavTile(
              icon: Icons.settings_outlined,
              label: 'Settings',
              selected: false,
              compact: compact,
              onTap: () => _go(() => context.push(AppRoutes.settings)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
    child: Text(
      text,
      style: const TextStyle(
        color: HomeColors.muted,
        fontSize: 11,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class _Brand extends StatelessWidget {
  const _Brand({required this.compact});
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final logo = Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [HomeColors.accent, HomeColors.accent2],
        ),
      ),
      child: const Icon(Icons.edit_note, color: Colors.white, size: 22),
    );
    if (compact) return Center(child: logo);
    return Row(
      children: [
        logo,
        const SizedBox(width: 10),
        const Text(
          'Viseth',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.compact,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final bool compact;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? Colors.white : HomeColors.muted;
    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 44,
            padding: compact
                ? EdgeInsets.zero
                : const EdgeInsets.symmetric(horizontal: 12),
            alignment: compact ? Alignment.center : Alignment.centerLeft,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: selected
                  ? HomeColors.accent.withValues(alpha: 0.22)
                  : Colors.transparent,
              border: Border.all(
                color: selected
                    ? HomeColors.accent.withValues(alpha: 0.5)
                    : Colors.transparent,
              ),
            ),
            child: compact
                ? Icon(icon, color: color, size: 22)
                : Row(
                    children: [
                      Icon(icon, color: color, size: 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: color,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
    return compact ? Tooltip(message: label, child: tile) : tile;
  }
}

// ---------------------------------------------------------------------------
// Header: title, search, New Note, more menu
// ---------------------------------------------------------------------------

class HomeHeader extends StatelessWidget {
  const HomeHeader({
    super.key,
    required this.title,
    required this.isRoot,
    required this.mobile,
    required this.onSearch,
    required this.onNewNote,
    required this.onNewFolder,
    required this.onImportImages,
    required this.onImportPdf,
    this.onMenu,
  });

  final String title;
  final bool isRoot;
  final bool mobile;
  final VoidCallback onSearch;
  final VoidCallback onNewNote;
  final VoidCallback onNewFolder;
  final VoidCallback onImportImages;
  final VoidCallback onImportPdf;
  final VoidCallback? onMenu;

  Future<void> _more(BuildContext anchor) async {
    final box = anchor.findRenderObject()! as RenderBox;
    final corner = box.localToGlobal(Offset(box.size.width, box.size.height));
    final v = await showGlassMenu<String>(
      context: anchor,
      position: Offset(corner.dx - 248, corner.dy + 6),
      items: const [
        GlassMenuItem(
          value: 'folder',
          icon: Icons.create_new_folder_outlined,
          label: 'New folder',
        ),
        GlassMenuItem(
          value: 'images',
          icon: Icons.add_photo_alternate_outlined,
          label: 'Import images',
        ),
        GlassMenuItem(
          value: 'pdf',
          icon: Icons.picture_as_pdf_outlined,
          label: 'Import PDF',
        ),
      ],
    );
    switch (v) {
      case 'folder':
        onNewFolder();
      case 'images':
        onImportImages();
      case 'pdf':
        onImportPdf();
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = mobile ? 16.0 : 24.0;
    return Padding(
      padding: EdgeInsets.fromLTRB(pad, mobile ? 8 : 20, pad, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (onMenu != null)
                GlassIconButton(
                  tooltip: 'Menu',
                  icon: const Icon(Icons.menu),
                  onPressed: onMenu,
                ),
              if (!isRoot)
                GlassIconButton(
                  tooltip: 'Back',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => context.canPop()
                      ? context.pop()
                      : context.go(AppRoutes.library),
                ),
              if (onMenu != null || !isRoot) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _SearchField(onTap: onSearch)),
              const SizedBox(width: 12),
              if (!mobile) ...[
                _NewNoteButton(onTap: onNewNote),
                const SizedBox(width: 8),
              ],
              Builder(
                builder: (ctx) => GlassIconButton(
                  tooltip: 'New folder, import',
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () => _more(ctx),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassSurface(
      radius: 16,
      elevated: false,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: const SizedBox(
            height: 48,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(Icons.search, color: HomeColors.muted, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Search notebooks and folders',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: HomeColors.muted),
                    ),
                  ),
                  Text(
                    'Ctrl+F',
                    style: TextStyle(color: HomeColors.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NewNoteButton extends StatelessWidget {
  const _NewNoteButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'New notebook (Ctrl+N)',
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            colors: [HomeColors.accent, HomeColors.accent2],
          ),
          boxShadow: [
            BoxShadow(
              color: HomeColors.accent.withValues(alpha: 0.45),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: onTap,
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add, color: Colors.white, size: 20),
                  SizedBox(width: 6),
                  Text(
                    'New Note',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}