import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/glass/glass_icon_button.dart';
import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../settings/application/settings_providers.dart';
import '../../settings/domain/layout_density.dart';
import '../application/favorites.dart';
import '../application/library_providers.dart';
import '../domain/folder.dart';
import '../domain/notebook.dart';
import 'widgets/favorite_star.dart';
import 'widgets/folder_card.dart';
import 'widgets/home_shell.dart';
import 'widgets/notebook_card.dart';

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favs = ref.watch(favoritesProvider);
    final folders = [
      for (final f in ref.watch(allFoldersProvider).value ?? const <Folder>[])
        if (favs.contains(f.id)) f,
    ];
    final notebooks = [
      for (final n
          in ref.watch(allNotebooksProvider).value ?? const <Notebook>[])
        if (favs.contains(n.id)) n,
    ];
    final accent = ref.watch(
      appSettingsProvider.select((s) => s.accentColorValue),
    );
    final compact = ref.watch(
      appSettingsProvider.select((s) => s.density == LayoutDensity.compact),
    );
    final showCovers = ref.watch(
      appSettingsProvider.select((s) => s.showCovers),
    );

    return Theme(
      data: AppTheme.build(
        Brightness.dark,
        seed: Color(accent),
        compact: compact,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final w = box.maxWidth;
          final mobile = w < 600;
          final rail = w >= 600 && w < 1000;
          final empty = folders.isEmpty && notebooks.isEmpty;

          return Scaffold(
            backgroundColor: HomeColors.bg,
            drawer: mobile
                ? Drawer(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    width: 288,
                    child: Builder(
                      builder: (dctx) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: HomeSidebar(
                          compact: false,
                          isRoot: false,
                          favoritesSelected: true,
                          afterTap: () => Navigator.of(dctx).pop(),
                        ),
                      ),
                    ),
                  )
                : null,
            body: HomeBackground(
              child: SafeArea(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!mobile)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: HomeSidebar(
                          compact: rail,
                          isRoot: false,
                          favoritesSelected: true,
                        ),
                      ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              mobile ? 16 : 24,
                              mobile ? 8 : 20,
                              16,
                              8,
                            ),
                            child: Row(
                              children: [
                                if (mobile)
                                  Builder(
                                    builder: (hctx) => GlassIconButton(
                                      tooltip: 'Menu',
                                      icon: const Icon(Icons.menu),
                                      onPressed: () =>
                                          Scaffold.of(hctx).openDrawer(),
                                    ),
                                  )
                                else
                                  GlassIconButton(
                                    tooltip: 'Back',
                                    icon: const Icon(Icons.chevron_left),
                                    onPressed: () => context.canPop()
                                        ? context.pop()
                                        : context.go(AppRoutes.library),
                                  ),
                                const SizedBox(width: 8),
                                const Expanded(
                                  child: Text(
                                    'Favorites',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 26,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: empty
                                ? const Center(
                                    child: Text(
                                      'No favorites yet. Tap the star on a '
                                      'folder or notebook.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: HomeColors.muted),
                                    ),
                                  )
                                : CustomScrollView(
                                    slivers: [
                                      if (folders.isNotEmpty) ...[
                                        _label('Folders', mobile),
                                        SliverPadding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: mobile ? 16 : 24,
                                          ),
                                          sliver: SliverGrid.builder(
                                            gridDelegate:
                                                const SliverGridDelegateWithMaxCrossAxisExtent(
                                                  maxCrossAxisExtent: 280,
                                                  mainAxisExtent: 60,
                                                  mainAxisSpacing: 12,
                                                  crossAxisSpacing: 12,
                                                ),
                                            itemCount: folders.length,
                                            itemBuilder: (context, i) =>
                                                FolderCard(
                                                  folder: folders[i],
                                                  onTap: () => context.push(
                                                    AppRoutes.folder(
                                                      folders[i].id,
                                                    ),
                                                  ),
                                                ),
                                          ),
                                        ),
                                      ],
                                      if (notebooks.isNotEmpty) ...[
                                        _label('Notebooks', mobile),
                                        SliverPadding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: mobile ? 16 : 24,
                                          ),
                                          sliver: SliverGrid.builder(
                                            gridDelegate:
                                                SliverGridDelegateWithMaxCrossAxisExtent(
                                                  maxCrossAxisExtent: mobile
                                                      ? 170
                                                      : 200,
                                                  childAspectRatio: 0.72,
                                                  mainAxisSpacing: 20,
                                                  crossAxisSpacing: 16,
                                                ),
                                            itemCount: notebooks.length,
                                            itemBuilder: (context, i) {
                                              final n = notebooks[i];
                                              return Stack(
                                                fit: StackFit.expand,
                                                children: [
                                                  NotebookCard(
                                                    notebook: n,
                                                    showCover: showCovers,
                                                    onTap: () => context.push(
                                                      AppRoutes.notebook(n.id),
                                                    ),
                                                  ),
                                                  Positioned(
                                                    top: 6,
                                                    right: 6,
                                                    child: FavoriteStar(
                                                      id: n.id,
                                                      name: n.title,
                                                      onCover: showCovers,
                                                    ),
                                                  ),
                                                ],
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                      const SliverToBoxAdapter(
                                        child: SizedBox(height: 48),
                                      ),
                                    ],
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static Widget _label(String text, bool mobile) => SliverToBoxAdapter(
    child: Padding(
      padding: EdgeInsets.fromLTRB(mobile ? 16 : 24, 16, 16, 12),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}
