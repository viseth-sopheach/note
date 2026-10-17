import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../application/library_providers.dart';

class LibrarySearchDelegate extends SearchDelegate<void> {
  LibrarySearchDelegate()
    : super(searchFieldLabel: 'Search notebooks and folders');

  @override
  List<Widget> buildActions(BuildContext context) => [
    if (query.isNotEmpty)
      IconButton(icon: const Icon(Icons.clear), onPressed: () => query = ''),
  ];

  @override
  Widget buildLeading(BuildContext context) => IconButton(
    icon: const Icon(Icons.arrow_back),
    onPressed: () => close(context, null),
  );

  @override
  Widget buildResults(BuildContext context) => _body();

  @override
  Widget buildSuggestions(BuildContext context) => _body();

  Widget _body() => Consumer(
    builder: (context, ref, _) {
      final q = query.trim();
      if (q.isEmpty) return const Center(child: Text('Type to search'));
      return ref
          .watch(searchProvider(q))
          .when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => const Center(child: Text('Search failed.')),
            data: (r) {
              if (r.folders.isEmpty && r.notebooks.isEmpty) {
                return const Center(child: Text('No results'));
              }
              void open(String location) {
                final router = GoRouter.of(context);
                close(context, null);
                router.push(location);
              }

              return ListView(
                children: [
                  for (final f in r.folders)
                    ListTile(
                      leading: const Icon(Icons.folder_outlined),
                      title: Text(f.name),
                      onTap: () => open(AppRoutes.folder(f.id)),
                    ),
                  for (final n in r.notebooks)
                    ListTile(
                      leading: Icon(
                        n.pdfPath != null
                            ? Icons.picture_as_pdf_outlined
                            : Icons.menu_book_outlined,
                      ),
                      title: Text(n.title),
                      onTap: () => open(AppRoutes.notebook(n.id)),
                    ),
                ],
              );
            },
          );
    },
  );
}
