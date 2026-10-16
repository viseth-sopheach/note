import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class TelegramConfig {
  const TelegramConfig({required this.botToken, required this.chatId});

  final String botToken;
  final String chatId;
}

class TelegramService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'telegram_bot_token';
  static const _chatKey = 'telegram_chat_id';

  Future<TelegramConfig?> loadConfig() async {
    final token = await _storage.read(key: _tokenKey);
    final chat = await _storage.read(key: _chatKey);
    if (token == null || token.isEmpty || chat == null || chat.isEmpty) {
      return null;
    }
    return TelegramConfig(botToken: token, chatId: chat);
  }

  Future<void> saveConfig(String botToken, String chatId) async {
    await _storage.write(key: _tokenKey, value: botToken.trim());
    await _storage.write(key: _chatKey, value: chatId.trim());
  }

  Future<void> clearConfig() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _chatKey);
  }

  Future<void> sendDocument(File file, {String? caption}) async {
    final config = await loadConfig();
    if (config == null) {
      throw StateError('Telegram is not set up. Open Settings > Telegram.');
    }
    final request =
        http.MultipartRequest(
            'POST',
            Uri.parse(
              'https://api.telegram.org/bot${config.botToken}/sendDocument',
            ),
          )
          ..fields['chat_id'] = config.chatId
          ..files.add(await http.MultipartFile.fromPath('document', file.path));
    if (caption != null) request.fields['caption'] = caption;

    final response = await http.Response.fromStream(await request.send());
    if (response.statusCode != 200) {
      throw HttpException(
        'Telegram error ${response.statusCode}: ${response.body}',
      );
    }
  }

  Future<void> openTelegram() =>
      launchUrl(Uri.parse('tg://'), mode: LaunchMode.externalApplication);
}
