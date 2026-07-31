import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../design/tokens.dart';
import '../../ui/components/app_snackbar.dart';
import '../../ui/components/settings/app_settings_section.dart';
import '../../ui/components/settings/settings_presentation.dart';

class SettingsSupportScreen extends StatelessWidget {
  const SettingsSupportScreen({super.key});

  static const _supportEmail = 'noreply@inpr1me.ru';
  static const _supportChatUrl = 'https://t.me/inpr1me_support';

  Future<void> _openUri(BuildContext context, Uri uri, String fallback) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (opened) return;
    await Clipboard.setData(ClipboardData(text: fallback));
    if (!context.mounted) return;
    showAppSnackBar(context, 'Не удалось открыть ссылку. Скопировал в буфер.');
  }

  Future<void> _openSupportEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      queryParameters: {
        'subject': 'ПРАЙМ: обращение в поддержку',
        'body': 'Здравствуйте! Опишите проблему здесь:',
      },
    );
    await _openUri(context, uri, _supportEmail);
  }

  Future<void> _openSupportChat(BuildContext context) async {
    await _openUri(context, Uri.parse(_supportChatUrl), _supportChatUrl);
  }

  Future<void> _copySupportChat(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _supportChatUrl));
    if (!context.mounted) return;
    showAppSnackBar(context, 'Ссылка на поддержку скопирована');
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPageScaffold(
      title: 'Поддержка',
      subtitle: 'Напишите нам — обычно отвечаем в течение рабочего дня.',
      children: [
        AppSettingsSection(
          title: 'Связаться',
          children: [
            AppSettingsTile(
              icon: Icons.alternate_email_rounded,
              title: 'Почта техподдержки',
              subtitle: _supportEmail,
              onTap: () => _openSupportEmail(context),
            ),
            AppSettingsTile(
              icon: Icons.chat_bubble_outline_rounded,
              title: 'Написать о проблеме',
              subtitle: 'Откроем чат в Telegram',
              onTap: () => _openSupportChat(context),
            ),
            AppSettingsTile(
              icon: Icons.copy_rounded,
              title: 'Скопировать чат поддержки',
              subtitle: _supportChatUrl,
              onTap: () => _copySupportChat(context),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        const SettingsInfoBanner(
          text:
              'При обращении укажите nickname и кратко опишите шаги, после которых возникла проблема.',
        ),
      ],
    );
  }
}
