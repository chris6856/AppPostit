import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../widgets/step_tile.dart';

class KeyboardSetupScreen extends StatelessWidget {
  const KeyboardSetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isIOS = defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      appBar: AppBar(title: const Text('Set Up the Keyboard')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Enable the AppPostIt keyboard once, then switch to it '
            'anytime you want to insert a saved post.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          if (isIOS) ...[
            const StepTile(
              number: 1,
              title: 'Open Settings > General > Keyboard > Keyboards',
              description: 'Then tap "Add New Keyboard...".',
            ),
            const StepTile(
              number: 2,
              title: 'Select "AppPostIt Keyboard"',
              description: 'Listed under "Third-Party Keyboards".',
            ),
            const StepTile(
              number: 3,
              title: 'Tap it again and turn on "Allow Full Access"',
              description: 'Required so the keyboard can track your free '
                  'post limit and read your saved posts -- AppPostIt '
                  "doesn't use this for anything else.",
            ),
            const StepTile(
              number: 4,
              title: 'Open any text field',
              description: 'Tap into a message, comment, or search box '
                  'to bring up your regular keyboard.',
            ),
            const StepTile(
              number: 5,
              title: 'Switch to AppPostIt',
              description: 'Tap and hold the globe icon in the bottom-left '
                  'of the keyboard and choose "AppPostIt Keyboard".',
            ),
            const StepTile(
              number: 6,
              title: 'Tap a category, then a post',
              description: "Its text is inserted right into the field "
                  "you're typing in.",
            ),
          ] else ...[
            const StepTile(
              number: 1,
              title: 'Open Settings and search "keyboard"',
              description: "Use your phone's Settings search bar -- the "
                  'exact menu location varies by phone.',
            ),
            const StepTile(
              number: 2,
              title: 'Open "On-screen keyboard" (or "Manage keyboards")',
            ),
            const StepTile(
              number: 3,
              title: 'Turn on "AppPostIt Keyboard"',
              description: 'You may see a warning about the keyboard '
                  'being able to see what you type -- this is normal for '
                  'any keyboard app.',
            ),
            const StepTile(
              number: 4,
              title: 'Open any text field',
              description: 'Tap into a message, comment, or search box '
                  'to bring up your regular keyboard.',
            ),
            const StepTile(
              number: 5,
              title: 'Switch to AppPostIt',
              description: 'Tap the keyboard-switcher icon (usually a '
                  'globe or keyboard icon) and choose "AppPostIt '
                  'Keyboard".',
            ),
            const StepTile(
              number: 6,
              title: 'Tap a category, then a post',
              description: "Its text is inserted right into the field "
                  "you're typing in.",
            ),
          ],
        ],
      ),
    );
  }
}
