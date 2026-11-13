<?php
// TEMPLATE for anthropic-config.php, which smart-reply.php requires.
// Copy this file to anthropic-config.php, fill in the real API key, and
// upload it next to smart-reply.php. anthropic-config.php is gitignored --
// never commit the real key.

// From https://platform.claude.com > API Keys. Set a monthly spend limit
// on the workspace too, as a final cap on cost.
define('ANTHROPIC_API_KEY', 'sk-ant-REPLACE_ME');

// Must match kSmartReplyAppToken in lib/services/smart_reply_service.dart.
// It ships inside the app, so it only keeps out casual scripts; the daily
// limits below are what really cap cost.
define('SMART_REPLY_APP_TOKEN', '412a78f3047288811ea070ad1624b7bccf2adf5e5df5c94a');

// The Claude model that writes replies. claude-haiku-5-5 is roughly 40x
// cheaper per reply if you'd rather trade some quality for cost.
define('SMART_REPLY_MODEL', 'claude-opus-5-5');

// Daily request caps (UTC days). Each Generate / Shorten / Regenerate tap
// is one request.
define('SMART_REPLY_DEVICE_DAILY_LIMIT', 25);
define('SMART_REPLY_IP_DAILY_LIMIT', 75);
define('SMART_REPLY_GLOBAL_DAILY_LIMIT', 1000);

// Where the per-day counters are kept. Best outside the public web folder,
// e.g. dirname(__DIR__) . '/smart-reply-data'. Defaults to the system temp
// directory when not set.
// define('SMART_REPLY_DATA_DIR', dirname(__DIR__) . '/smart-reply-data');
