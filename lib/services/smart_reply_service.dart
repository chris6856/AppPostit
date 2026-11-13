import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// The PHP endpoint (website/smart-reply.php) that holds the Anthropic API
/// key and calls Claude. The key itself never ships in the app.
final Uri kSmartReplyEndpoint =
    Uri.parse('https://apppostit.com/smart-reply.php');

/// Must match SMART_REPLY_APP_TOKEN in the server's anthropic-config.php.
/// Not a real secret (anyone can extract it from the app); it only keeps
/// casual scripts off the endpoint. The server's daily limits cap cost.
const String kSmartReplyAppToken =
    '412a78f3047288811ea070ad1624b7bccf2adf5e5df5c94a';

const String smartReplyDeviceIdKey = 'smart_reply_device_id';

enum ReplyTone {
  helpful('Helpful'),
  professional('Professional'),
  casual('Casual');

  const ReplyTone(this.label);
  final String label;
}

class SmartReplyException implements Exception {
  SmartReplyException(this.message, {this.isDailyLimit = false});
  final String message;
  final bool isDailyLimit;

  @override
  String toString() => message;
}

class SmartReplyService {
  SmartReplyService(this._prefs, {http.Client? client})
      : _client = client ?? http.Client();

  final SharedPreferences _prefs;
  final http.Client _client;

  /// A random per-install ID the server uses for its per-device daily
  /// limit. Not tied to the user or the hardware.
  String get _deviceId {
    final existing = _prefs.getString(smartReplyDeviceIdKey);
    if (existing != null) return existing;
    final random = Random.secure();
    final id = List.generate(16, (_) => random.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    _prefs.setString(smartReplyDeviceIdKey, id);
    return id;
  }

  /// Drafts a reply to [message]. With [draftToShorten], asks for a
  /// shorter version of that draft instead.
  Future<String> generate({
    required String message,
    required String profileName,
    required String profileInstructions,
    required ReplyTone tone,
    List<String> examples = const [],
    String? draftToShorten,
  }) async {
    final body = jsonEncode({
      'mode': draftToShorten == null ? 'generate' : 'shorten',
      'message': message,
      'profile_name': profileName,
      'profile_instructions': profileInstructions,
      'tone': tone.name,
      'examples': examples,
      'draft': ?draftToShorten,
      'device_id': _deviceId,
    });

    final http.Response response;
    try {
      response = await _client
          .post(
            kSmartReplyEndpoint,
            headers: {
              'Content-Type': 'application/json',
              'X-AppPostIt-Key': kSmartReplyAppToken,
            },
            body: body,
          )
          .timeout(const Duration(seconds: 100));
    } on TimeoutException {
      throw SmartReplyException(
        'Smart Reply took too long to respond. Please try again.',
      );
    } on SocketException {
      throw SmartReplyException(
        "Couldn't connect. Check your internet connection and try again.",
      );
    } on http.ClientException {
      throw SmartReplyException(
        "Couldn't connect. Check your internet connection and try again.",
      );
    }

    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      // Fall through to the generic error below.
    }

    if (response.statusCode == 200 && json?['reply'] is String) {
      return json!['reply'] as String;
    }
    final serverMessage = json?['error'];
    throw SmartReplyException(
      serverMessage is String && serverMessage.isNotEmpty
          ? serverMessage
          : 'Something went wrong generating a reply. Please try again.',
      isDailyLimit: response.statusCode == 429,
    );
  }

  void dispose() => _client.close();
}
