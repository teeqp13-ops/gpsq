<?php
/**
 * صفحة التحقق من الكود — redeem.php
 * صفحة عامة (بدون تسجيل دخول) تتيح للمستخدم التحقق من صلاحية كود التفعيل.
 */

require_once __DIR__ . '/api/config.php';

$result = null;
$code   = '';

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $code = strtoupper(trim($_POST['code'] ?? ''));

    if ($code === '') {
        $result = ['ok' => false, 'msg' => 'الرجاء إدخال الكود'];
    } else {
        $db   = getDB();
        $stmt = $db->prepare('SELECT status, device_name, activated_at FROM codes WHERE code = ?');
        $stmt->execute([$code]);
        $row = $stmt->fetch();

        if (!$row) {
            $result = ['ok' => false, 'msg' => 'الكود غير موجود أو غير صحيح'];
        } else {
            switch ($row['status']) {
                case 'unused':
                    $result = ['ok' => true,  'status' => 'unused',  'msg' => 'الكود صالح وغير مستخدم بعد'];
                    break;
                case 'linked':
                    $result = ['ok' => true,  'status' => 'linked',  'msg' => 'الكود مفعَّل ومرتبط بجهاز'];
                    break;
                case 'expired':
                    $result = ['ok' => false, 'status' => 'expired', 'msg' => 'انتهت صلاحية هذا الكود'];
                    break;
                case 'closed':
                    $result = ['ok' => false, 'status' => 'closed',  'msg' => 'هذا الكود مغلق'];
                    break;
                default:
                    $result = ['ok' => false, 'msg' => 'حالة الكود غير معروفة'];
            }
        }
    }
}

function e(string $s): string
{
    return htmlspecialchars($s, ENT_QUOTES, 'UTF-8');
}
?>
<!DOCTYPE html>
<html lang="ar" dir="rtl">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>GPS Plus — التحقق من كود التفعيل</title>
<style>
  :root {
    --bg:      #0f0f14;
    --surface: #1a1a24;
    --card:    #22223a;
    --border:  #2e2e48;
    --accent:  #7c6fff;
    --text:    #e5e7eb;
    --muted:   #9ca3af;
    --success: #22c55e;
    --danger:  #ef4444;
    --warning: #f59e0b;
    --info:    #3b82f6;
  }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body {
    background: var(--bg);
    color: var(--text);
    font-family: 'Segoe UI', Tahoma, Arial, sans-serif;
    min-height: 100vh;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 20px;
  }
  .card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 16px;
    padding: 36px 32px;
    width: 100%;
    max-width: 420px;
  }
  .logo {
    text-align: center;
    margin-bottom: 24px;
  }
  .logo h1 { color: var(--accent); font-size: 1.4rem; }
  .logo p  { color: var(--muted);  font-size: .88rem; margin-top: 4px; }

  label {
    display: block;
    font-size: .88rem;
    color: var(--muted);
    margin-bottom: 6px;
  }
  input[type=text] {
    width: 100%;
    background: var(--card);
    border: 1px solid var(--border);
    color: var(--text);
    border-radius: 10px;
    padding: 12px 16px;
    font-size: 1.1rem;
    letter-spacing: .12em;
    text-transform: uppercase;
    outline: none;
    text-align: center;
    font-family: monospace;
  }
  input[type=text]:focus { border-color: var(--accent); }

  button {
    margin-top: 14px;
    width: 100%;
    padding: 12px;
    border-radius: 10px;
    border: none;
    background: var(--accent);
    color: #fff;
    font-size: 1rem;
    font-weight: 700;
    cursor: pointer;
    transition: .2s;
  }
  button:hover { opacity: .87; }

  .result {
    margin-top: 20px;
    border-radius: 10px;
    padding: 16px 18px;
    text-align: center;
    font-size: .95rem;
    font-weight: 600;
  }
  .result-ok  { background: rgba(34,197,94,.15); border: 1px solid rgba(34,197,94,.35); color: #86efac; }
  .result-err { background: rgba(239,68,68,.15); border: 1px solid rgba(239,68,68,.35); color: #fca5a5; }
  .result-warn{ background: rgba(245,158,11,.15);border: 1px solid rgba(245,158,11,.35); color: #fcd34d; }

  .badge-row {
    margin-top: 10px;
    font-size: .82rem;
    color: var(--muted);
  }

  footer {
    margin-top: 28px;
    font-size: .78rem;
    color: var(--border);
    text-align: center;
  }
</style>
</head>
<body>

<div class="card">
  <div class="logo">
    <h1>🛰️ GPS Plus</h1>
    <p>التحقق من كود التفعيل</p>
  </div>

  <form method="post">
    <label for="code">أدخل كود التفعيل</label>
    <input
      type="text"
      id="code"
      name="code"
      value="<?= e($code) ?>"
      placeholder="XXXXXXXX"
      maxlength="32"
      autocomplete="off"
      autofocus
      required
    >
    <button type="submit">🔍 تحقق من الكود</button>
  </form>

  <?php if ($result !== null): ?>
    <?php
      $cls = 'result-err';
      if ($result['ok']) {
          $cls = isset($result['status']) && $result['status'] === 'linked' ? 'result-ok' : 'result-ok';
      } elseif (isset($result['status']) && $result['status'] === 'expired') {
          $cls = 'result-warn';
      }
    ?>
    <div class="result <?= $cls ?>">
      <?php if ($result['ok']): ?>
        <?= $result['status'] === 'linked' ? '✅' : '🟢' ?>
      <?php else: ?>
        <?= (($result['status'] ?? '') === 'expired') ? '⏰' : '❌' ?>
      <?php endif; ?>
      <?= e($result['msg']) ?>
    </div>
  <?php endif; ?>
</div>

<footer>GPS Plus &copy; <?= date('Y') ?></footer>

</body>
</html>
