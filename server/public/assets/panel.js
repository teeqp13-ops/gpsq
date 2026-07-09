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
    } catch (_) {}
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
});
