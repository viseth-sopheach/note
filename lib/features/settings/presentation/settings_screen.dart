import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/glass/glass_backdrop.dart';
import 'sections/about_section.dart';
import 'sections/appearance_section.dart';
import 'sections/editor_section.dart';
import 'sections/integrations_section.dart';
import 'sections/paper_section.dart';
import 'widgets/settings_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const double _maxWidth = 720;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leadingWidth: 60,
        leading: const SettingsBackButton(),
        title: const Text('Settings'),
      ),
      body: GlassBackdrop(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final side = math.max(16.0, (constraints.maxWidth - _maxWidth) / 2);
            return ListView(
              padding: EdgeInsets.fromLTRB(side, 8, side, 32),
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
      ),
    );
  }
}
