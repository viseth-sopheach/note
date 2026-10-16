import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'sections/about_section.dart';
import 'sections/appearance_section.dart';
import 'sections/editor_section.dart';
import 'sections/integrations_section.dart';
import 'sections/paper_section.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const double _maxWidth = 720;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final side = math.max(16.0, (constraints.maxWidth - _maxWidth) / 2);
          return ListView(
            padding: EdgeInsets.symmetric(horizontal: side, vertical: 16),
            children: const [
              AppearanceSection(),
              PaperSection(),
              EditorSection(),
              IntegrationsSection(),
              AboutSection(),
            ],
          );
        },
      ),
    );
  }
}
