(function () {
  const items = Array.from(document.querySelectorAll('.menu-item'));
  const descText = document.getElementById('desc-text');
  let index = 0;

  function select(i) {
    index = (i + items.length) % items.length;
    items.forEach((el, n) => el.classList.toggle('selected', n === index));
    descText.textContent = items[index].dataset.desc || '';
  }

  function activate() {
    const action = items[index].dataset.action;
    dispatchAction(action);
  }

  function dispatchAction(action) {
    // Hook these to your engine via CEF JS bindings (e.g. window.engine.*)
    // Replace console.log calls with real bindings when wired up.
    switch (action) {
      case 'map_browser':  window.engine?.openMapBrowser?.();   break;
      case 'start_server': window.engine?.startServer?.();      break;
      case 'settings':     window.engine?.openSettings?.();     break;
      case 'legacy_menu':  window.engine?.openLegacyMenu?.();   break;
      case 'quit':         window.engine?.quit?.();             break;
      default: console.log('Unknown action:', action);
    }
    console.log('[menu] action =>', action);
  }

  // Mouse
  items.forEach((el, i) => {
    el.addEventListener('mouseenter', () => select(i));
    el.addEventListener('click', activate);
  });

  // Keyboard
  document.addEventListener('keydown', (e) => {
    switch (e.key) {
      case 'ArrowUp':   case 'w': select(index - 1); e.preventDefault(); break;
      case 'ArrowDown': case 's': select(index + 1); e.preventDefault(); break;
      case 'Enter':     case ' ': activate();        e.preventDefault(); break;
    }
  });

  // Initial state
  select(0);
})();
