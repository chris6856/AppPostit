<?php
// Handles the AppPostIt contact form submission (contact.html) and emails it
// to admin@apppostit.com. Requires the admin@apppostit.com mailbox to exist
// on this hosting account so mail() can send as that domain.

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    header('Location: contact.html');
    exit;
}

$name = trim($_POST['name'] ?? '');
$email = trim($_POST['email'] ?? '');
$message = trim($_POST['message'] ?? '');
$honeypot = trim($_POST['website'] ?? '');

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

$to = 'admin@apppostit.com';
$subject = 'AppPostIt contact form: ' . $name;

$body = "New message from the AppPostIt contact form:\n\n";
$body .= "Name: $name\n";
$body .= "Email: $email\n\n";
$body .= "Message:\n$message\n";

$headers = "From: AppPostIt Website <admin@apppostit.com>\r\n";
$headers .= "Reply-To: $email\r\n";
$headers .= "X-Mailer: PHP/" . phpversion();

$sent = mail($to, $subject, $body, $headers);

header('Location: contact.html?' . ($sent ? 'sent=1' : 'error=1'));
exit;
