import 'package:flutter/material.dart';

import '../../core/app_settings.dart';

class ThemeLanguageBottomSheet extends StatelessWidget {
  const ThemeLanguageBottomSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (_) => const ThemeLanguageBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppSettings.instance;
    return SafeArea(
      top: false,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: Text(AppSettings.text(context, 'Chế độ tối', 'Dark mode')),
              value: settings.dark,
              onChanged: settings.setDark,
            ),
            ListTile(
              title: Text(AppSettings.text(context, 'Ngôn ngữ', 'Language')),
              trailing: DropdownButton<String>(
                value: settings.locale.languageCode,
                items: const [
                  DropdownMenuItem(value: 'vi', child: Text('Tiếng Việt')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: (code) {
                  if (code != null) settings.setLanguage(code);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
