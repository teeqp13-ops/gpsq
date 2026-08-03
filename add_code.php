<?php
// أداة بسيطة لإضافة أكواد جديدة (يجب حذفها بعد الاستخدام أو حمايتها بكلمة مرور)
$newCode = "WLL-FOX-2026"; // الكود الذي تريد إضافته
$expiry = "2027-01-01";

$dbFile = 'database.json';
$db = json_decode(file_get_contents($dbFile), true);

$db['codes'][$newCode] = [
    'udid' => '',
    'expiry' => $expiry,
    'status' => 'active'
];

file_put_contents($dbFile, json_encode($db, JSON_PRETTY_PRINT));
echo "Code Added Successfully!";
?>
