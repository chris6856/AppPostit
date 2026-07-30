<?php
// Handles the AppPostIt contact form submission (contact.html) and sends it
// via SendGrid's API. Requires sendgrid-config.php (gitignored -- upload it
// separately to the server with a real API key filled in) to exist
// alongside this file.

$configPath = __DIR__ . '/sendgrid-config.php';
if (!file_exists($configPath)) {
    header('Location: contact.html?error=1');
    exit;
}
require $configPath;

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: contact.html');
    exit;
}

$name = trim($_POST['name'] ?? '');
$email = trim($_POST['email'] ?? '');
$message = trim($_POST['message'] ?? '');
$honeypot = trim($_POST['hp_9f3a'] ?? '');

// Spam trap: bots tend to fill every field, including hidden ones. Pretend
// success without sending anything.
if ($honeypot !== '') {
    header('Location: contact.html?sent=1');
    exit;
}

if ($name === '' || $message === '' || !filter_var($email, FILTER_VALIDATE_EMAIL)) {
    header('Location: contact.html?error=1');
    exit;
}

$body = "New message from the AppPostIt contact form:\n\n";
$body .= "Name: $name\n";
$body .= "Email: $email\n\n";
$body .= "Message:\n$message\n";

$payload = [
    'personalizations' => [[
        'to' => [['email' => CONTACT_TO_EMAIL]],
    ]],
    'from' => [
        'email' => SENDGRID_FROM_EMAIL,
        'name' => SENDGRID_FROM_NAME,
    ],
    'reply_to' => [
        'email' => $email,
        'name' => $name,
    ],
    'subject' => 'AppPostIt contact form: ' . $name,
    'content' => [[
        'type' => 'text/plain',
        'value' => $body,
    ]],
];

$sent = false;

if (function_exists('curl_init')) {
    $ch = curl_init('https://api.sendgrid.com/v3/mail/send');
    curl_setopt($ch, CURLOPT_POST, true);
    curl_setopt($ch, CURLOPT_HTTPHEADER, [
        'Authorization: Bearer ' . SENDGRID_API_KEY,
        'Content-Type: application/json',
    ]);
    curl_setopt($ch, CURLOPT_POSTFIELDS, json_encode($payload));
    curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
    curl_setopt($ch, CURLOPT_TIMEOUT, 10);
    curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);

    // SendGrid returns 202 Accepted on a successful send request.
    $sent = ($httpCode === 202);
}

header('Location: contact.html?' . ($sent ? 'sent=1' : 'error=1'));
exit;
