(() => {
  const card = document.getElementById('termcard');
  if (!card) return;

  const title = card.querySelector('.termcard-title');
  const full = card.querySelector('.termcard-full');
  const definition = card.querySelector('.termcard-def');
  const terms = [...document.querySelectorAll('.term')];
  if (!title || !full || !definition || !terms.length) return;

  let active = null;
  let closeTimer = null;

  function clearTimer() {
    if (closeTimer) clearTimeout(closeTimer);
    closeTimer = null;
  }

  function closeCard() {
    clearTimer();
    if (active) active.setAttribute('aria-expanded', 'false');
    active = null;
    card.classList.remove('open');
    card.setAttribute('aria-hidden', 'true');
  }

  function safeTop() {
    const nav = document.querySelector('[data-term-nav], .nav, nav');
    if (!nav) return 12;
    const position = getComputedStyle(nav).position;
    return /sticky|fixed/.test(position) ? nav.getBoundingClientRect().bottom + 8 : 12;
  }

  function positionCard(term) {
    const rect = term.getBoundingClientRect();
    const width = Math.min(350, window.innerWidth - 24);
    const left = Math.max(12, Math.min(window.innerWidth - width - 12,
      rect.left + rect.width / 2 - width / 2));
    card.style.width = `${width}px`;
    card.style.left = `${left}px`;

    const height = card.offsetHeight;
    const lowerBound = Math.max(12, Math.min(safeTop(), window.innerHeight - height - 12));
    const upperBound = Math.max(lowerBound, window.innerHeight - height - 12);
    const below = rect.bottom + 10;
    const preferred = below + height <= window.innerHeight - 12
      ? below
      : rect.top - height - 10;
    card.style.top = `${Math.max(lowerBound, Math.min(upperBound, preferred))}px`;
  }

  function openCard(term) {
    clearTimer();
    if (active && active !== term) active.setAttribute('aria-expanded', 'false');
    active = term;
    title.textContent = term.dataset.title || term.textContent.trim();
    full.textContent = term.dataset.full || '';
    definition.textContent = term.dataset.def || '';
    term.setAttribute('aria-expanded', 'true');
    card.setAttribute('aria-hidden', 'false');
    card.classList.add('open');
    positionCard(term);
  }

  function scheduleClose() {
    clearTimer();
    closeTimer = setTimeout(() => {
      if (!card.matches(':hover') && !(active && active.matches(':hover'))) closeCard();
    }, 90);
  }

  terms.forEach(term => {
    term.setAttribute('role', 'button');
    term.setAttribute('tabindex', '0');
    term.setAttribute('aria-haspopup', 'true');
    term.setAttribute('aria-expanded', 'false');
    term.setAttribute('aria-controls', card.id);
    term.addEventListener('mouseenter', () => openCard(term));
    term.addEventListener('mouseleave', scheduleClose);
    term.addEventListener('focus', () => openCard(term));
    term.addEventListener('blur', scheduleClose);
    term.addEventListener('click', event => {
      event.stopPropagation();
      openCard(term);
    });
    term.addEventListener('keydown', event => {
      if (event.key === 'Escape') {
        closeCard();
        term.blur();
      }
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        openCard(term);
      }
    });
  });

  card.addEventListener('mouseenter', clearTimer);
  card.addEventListener('mouseleave', scheduleClose);
  document.addEventListener('click', event => {
    if (!event.target.closest('.term') && !event.target.closest('.termcard')) closeCard();
  });
  window.addEventListener('resize', () => { if (active) positionCard(active); });
  window.addEventListener('scroll', closeCard, { passive: true });
})();
