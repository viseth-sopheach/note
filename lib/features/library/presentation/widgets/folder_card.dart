import 'package:flutter/material.dart';

import '../../domain/folder.dart';

class FolderCard extends StatelessWidget {
  const FolderCard({super.key, required this.folder, required this.onTap});

  final Folder folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(
                Icons.folder_outlined,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  folder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
