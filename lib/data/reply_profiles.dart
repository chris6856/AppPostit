import 'dart:convert';

/// A Smart Reply response profile: a name plus instructions describing the
/// kind of reply to write. Built-in profiles ship with the app; custom ones
/// are created by the user and kept in SharedPreferences (small, few, and
/// app-only, so they don't need the keyboard-shared database).
class ReplyProfile {
  const ReplyProfile({
    required this.id,
    required this.name,
    required this.instructions,
    this.isBuiltIn = false,
  });

  final String id;
  final String name;
  final String instructions;
  final bool isBuiltIn;

  ReplyProfile copyWith({String? name, String? instructions}) => ReplyProfile(
        id: id,
        name: name ?? this.name,
        instructions: instructions ?? this.instructions,
        isBuiltIn: isBuiltIn,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'instructions': instructions};

  static ReplyProfile? fromJson(Object? json) {
    if (json is! Map) return null;
    final id = json['id'];
    final name = json['name'];
    final instructions = json['instructions'];
    if (id is! String || name is! String || instructions is! String) {
      return null;
    }
    return ReplyProfile(id: id, name: name, instructions: instructions);
  }
}

const List<ReplyProfile> builtInReplyProfiles = [
  ReplyProfile(
    id: 'builtin_general',
    name: 'General',
    instructions: 'Write a clear, friendly reply that directly answers or '
        'acknowledges the message.',
    isBuiltIn: true,
  ),
  ReplyProfile(
    id: 'builtin_customer_support',
    name: 'Customer Support',
    instructions: 'Reply as a customer support representative. Acknowledge '
        "the customer's issue with empathy, explain what can be done, and "
        'give clear next steps. Do not promise refunds, replacements or '
        'policies that are not stated in my saved posts.',
    isBuiltIn: true,
  ),
  ReplyProfile(
    id: 'builtin_technical_support',
    name: 'Technical Support',
    instructions: 'Reply as a technical support specialist. Identify the '
        'likely cause, give troubleshooting steps in order, and ask for '
        'any missing details needed to diagnose the problem.',
    isBuiltIn: true,
  ),
  ReplyProfile(
    id: 'builtin_sales',
    name: 'Sales',
    instructions: 'Reply as a helpful salesperson. Answer the question, '
        'highlight the benefits most relevant to what they asked about, '
        'and end with a low-pressure next step. Never be pushy.',
    isBuiltIn: true,
  ),
  ReplyProfile(
    id: 'builtin_social_media',
    name: 'Social Media',
    instructions: 'Reply to a public social media post or comment. Keep it '
        'short and conversational, add something genuinely useful, and '
        'avoid hashtags and sales language unless the post invites it.',
    isBuiltIn: true,
  ),
];

const String customReplyProfilesKey = 'smart_reply_custom_profiles';

List<ReplyProfile> decodeCustomProfiles(String? stored) {
  if (stored == null || stored.isEmpty) return [];
  try {
    final decoded = jsonDecode(stored);
    if (decoded is! List) return [];
    return decoded.map(ReplyProfile.fromJson).whereType<ReplyProfile>().toList();
  } catch (_) {
    return [];
  }
}

String encodeCustomProfiles(List<ReplyProfile> profiles) =>
    jsonEncode(profiles.map((p) => p.toJson()).toList());
