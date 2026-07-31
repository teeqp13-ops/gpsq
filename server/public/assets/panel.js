document.addEventListener('click', async (e) => {
  const btn = e.target.closest('.copy-btn');
  if (btn) {
    try {
      await navigator.clipboard.writeText(btn.dataset.copy || '');
      const old = btn.textContent;
      btn.textContent = 'تم النسخ';
      btn.classList.add('done');
      setTimeout(() => {
        btn.textContent = old;
        btn.classList.remove('done');
      }, 1200);
    } catch (_) {
      alert('تعذر النسخ تلقائياً');
    }
  }

  const selected = e.target.closest('.copy-selected');
  if (selected) {
    const codes = [...document.querySelectorAll('.row-check:checked')]
      .map(i => i.dataset.code)
      .filter(Boolean);
    if (!codes.length) return alert('اختر أكواد أولاً');
    await navigator.clipboard.writeText(codes.join('\n'));
    selected.textContent = 'تم نسخ المحدد';
    setTimeout(() => selected.textContent = 'نسخ المحدد', 1200);
  }

  const generated = e.target.closest('.copy-generated');
  if (generated) {
    const field = document.getElementById('generated_codes');
    if (!field?.value) return;
    await navigator.clipboard.writeText(field.value);
    generated.textContent = 'تم نسخ جميع الأكواد';
    setTimeout(() => generated.textContent = 'نسخ جميع الأكواد', 1200);
  }

  const bulk = e.target.closest('.bulk-action');
  if (bulk) {
    const codes = [...document.querySelectorAll('.row-check:checked')]
      .map(i => i.dataset.code)
      .filter(Boolean);
    if (!codes.length) return alert('اختر أكواد أولاً');
    const action = bulk.dataset.action || '';
    if ((action === 'delete' || action === 'stop') &&
        !confirm(action === 'delete' ? 'حذف الأكواد المحددة نهائيًا؟' : 'إيقاف الأكواد المحددة؟')) {
      return;
    }
    const form = document.getElementById('bulk-form');
    const actionField = document.getElementById('bulk-action-value');
    const values = document.getElementById('bulk-code-values');
    if (!form || !actionField || !values) return;
    actionField.value = action;
    values.replaceChildren(...codes.map(code => {
      const input = document.createElement('input');
      input.type = 'hidden';
      input.name = 'selected_codes[]';
      input.value = code;
      return input;
    }));
    form.submit();
  }

  const toggle = e.target.closest('.toggle-secret');
  if (toggle) {
    const row = toggle.closest('tr');
    const secret = row?.querySelector('[data-secret]');
    if (!secret) return;
    const isMasked = secret.classList.toggle('masked');
    toggle.textContent = isMasked ? 'إظهار' : 'إخفاء';
  }
});
