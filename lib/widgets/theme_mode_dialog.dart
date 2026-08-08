import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/providers.dart';

Future<void> showThemeModeDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (context) => const _ThemeModeDialog(),
  );
}

class _ThemeModeDialog extends ConsumerWidget {
  const _ThemeModeDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    return SimpleDialog(
      title: const Text('Theme'),
      children: [
        RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (value) {
            if (value == null) return;
            setThemeMode(ref, value);
            Navigator.of(context).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final mode in ThemeMode.values)
                RadioListTile<ThemeMode>(
                  title: Text(_label(mode)),
                  value: mode,
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _label(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'Light',
        ThemeMode.dark => 'Dark',
        ThemeMode.system => 'System default',
      };
}
