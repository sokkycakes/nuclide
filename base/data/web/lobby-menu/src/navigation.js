// Navigation stays outside the components; native input editing is never intercepted.
export function installNavigation(root, onCancel) {
  function controls() {
    const scope = root.querySelector('[aria-modal="true"]') || root;
    return Array.from(scope.querySelectorAll('button:not(:disabled),input:not(:disabled)'))
      .filter(el => el.tabIndex >= 0 && el.getClientRects().length);
  }
  function keydown(e) {
    if (e.defaultPrevented || e.isComposing) return;
    const input = e.target && /^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName);
    if (e.key === 'Escape') {
      e.preventDefault(); onCancel(); return;
    }
    // Let the engine handle its console shortcut and let fields handle editing keys.
    if (e.ctrlKey || e.altKey || e.metaKey || (input && e.key !== 'Tab')) return;
    if ((e.key === 'Enter' || e.key === ' ' || e.key === 'Spacebar') && e.target.tagName === 'BUTTON') {
      e.preventDefault();
      if (!e.target.disabled) e.target.click();
      return;
    }
    const backward = ['ArrowUp', 'ArrowLeft', 'w', 'W'].indexOf(e.key) !== -1 || (e.key === 'Tab' && e.shiftKey);
    const forward = ['ArrowDown', 'ArrowRight', 's', 'S'].indexOf(e.key) !== -1 || (e.key === 'Tab' && !e.shiftKey);
    if (!backward && !forward) return;
    const menu = e.target.closest && e.target.closest('.lobby-menu');
    const all = menu && e.key !== 'Tab'
      ? Array.from(menu.querySelectorAll('[data-lobby-index]:not(:disabled)'))
      : controls();
    if (!all.length) return;
    e.preventDefault();
    const index = all.indexOf(document.activeElement);
    all[(index + (backward ? -1 : 1) + all.length) % all.length].focus();
  }
  root.addEventListener('keydown', keydown);
  return () => root.removeEventListener('keydown', keydown);
}

export function focusFirst(root) {
  const el = root && root.querySelector('button:not(:disabled):not([tabindex="-1"]),input:not(:disabled)');
  if (el) el.focus();
}
