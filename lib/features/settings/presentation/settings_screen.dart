import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'sections/about_section.dart';
import 'sections/appearance_section.dart';
import 'sections/editor_section.dart';
import 'sections/integrations_section.dart';
import 'sections/paper_section.dart';
import 'widgets/settings_background.dart';
import 'widgets/settings_widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const double _maxWidth = 720;
  static const double _wideBreak = 1100;
  static const double _wideMax = 1200;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + kToolbarHeight + 8;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        leadingWidth: 60,
        leading: const SettingsBackButton(),
        title: const Text('Settings'),
      ),
      body: SettingsBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;

            if (w >= _wideBreak) {
              final side = math.max(24.0, (w - _wideMax) / 2);
              return SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(side, top, side, 32),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        children: [AppearanceSection(), PaperSection()],
                      ),
                    ),
                    SizedBox(width: 24),
                    Expanded(
                      child: Column(
                        children: [
                          EditorSection(),
                          IntegrationsSection(),
                          AboutSection(),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }

            final side = math.max(16.0, (w - _maxWidth) / 2);
            return ListView(
              padding: EdgeInsets.fromLTRB(side, top, side, 32),
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
