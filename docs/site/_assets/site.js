// Optune docs site — Peekaboo-inspired interactions.

(() => {
  // Theme toggle
  const root = document.documentElement;
  const toggle = document.querySelector('[data-theme-toggle]');
  const label = toggle?.querySelector('.theme-toggle__label');
  const setLabel = () => {
    if (!label) return;
    label.textContent = root.dataset.theme === 'light' ? 'Light' : 'Dark';
  };
  setLabel();
  toggle?.addEventListener('click', () => {
    const next = root.dataset.theme === 'light' ? 'dark' : 'light';
    root.dataset.theme = next;
    try { localStorage.setItem('optune-theme', next); } catch {}
    setLabel();
  });

  // Sidebar mobile
  const navToggle = document.querySelector('.nav-toggle');
  const sidebar = document.querySelector('.sidebar');
  navToggle?.addEventListener('click', () => {
    const open = sidebar.classList.toggle('open');
    navToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
  });
  document.addEventListener('click', (e) => {
    if (!sidebar?.classList.contains('open')) return;
    if (sidebar.contains(e.target) || navToggle.contains(e.target)) return;
    sidebar.classList.remove('open');
    navToggle.setAttribute('aria-expanded', 'false');
  });

  // Sidebar search filter
  const search = document.querySelector('.search input');
  const navLinks = Array.from(document.querySelectorAll('.nav-link'));
  search?.addEventListener('input', () => {
    const q = search.value.trim().toLowerCase();
    navLinks.forEach(a => {
      const match = !q || a.textContent.toLowerCase().includes(q);
      a.style.display = match ? '' : 'none';
    });
    // Hide section headings that have no visible children
    document.querySelectorAll('nav section').forEach(sec => {
      const visible = Array.from(sec.querySelectorAll('.nav-link')).some(a => a.style.display !== 'none');
      sec.style.display = visible ? '' : 'none';
    });
  });

  // Copy buttons on pre blocks
  document.querySelectorAll('.doc pre').forEach(pre => {
    const btn = document.createElement('button');
    btn.className = 'copy';
    btn.type = 'button';
    btn.textContent = 'Copy';
    btn.addEventListener('click', async () => {
      const text = pre.querySelector('code')?.textContent ?? pre.textContent;
      try {
        await navigator.clipboard.writeText(text.replace(/\n$/, ''));
        btn.textContent = 'Copied';
        btn.classList.add('copied');
        setTimeout(() => { btn.textContent = 'Copy'; btn.classList.remove('copied'); }, 1400);
      } catch {
        btn.textContent = 'Press ⌘C';
      }
    });
    pre.appendChild(btn);
  });

  // Anchor links on headings
  document.querySelectorAll('.doc :is(h2,h3,h4)').forEach(h => {
    if (!h.id) return;
    const a = document.createElement('a');
    a.className = 'anchor';
    a.href = `#${h.id}`;
    a.setAttribute('aria-label', `Anchor link to ${h.textContent}`);
    a.textContent = '#';
    h.prepend(a);
  });

  // TOC active highlight via IntersectionObserver
  const tocLinks = Array.from(document.querySelectorAll('.toc a'));
  if (tocLinks.length) {
    const tocMap = new Map(tocLinks.map(a => [a.getAttribute('href').slice(1), a]));
    const headings = Array.from(document.querySelectorAll('.doc :is(h2,h3,h4)')).filter(h => tocMap.has(h.id));
    const visible = new Set();
    const setActive = () => {
      tocLinks.forEach(a => a.classList.remove('active'));
      // Pick the topmost visible heading
      const ordered = headings.filter(h => visible.has(h.id));
      const winner = ordered[0] || headings.find(h => visible.has(h.id));
      if (winner) tocMap.get(winner.id)?.classList.add('active');
    };
    const obs = new IntersectionObserver((entries) => {
      entries.forEach(e => {
        if (e.isIntersecting) visible.add(e.target.id);
        else visible.delete(e.target.id);
      });
      setActive();
    }, { rootMargin: '-15% 0% -75% 0%', threshold: 0 });
    headings.forEach(h => obs.observe(h));
  }
})();
