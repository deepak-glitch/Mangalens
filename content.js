// MangaLens — content.js v7
// Auto-translate on scroll · Near-perfect overlay alignment · Batch-aware

(function () {
  'use strict';

  // ── Site config ────────────────────────────────────────────────────────────
  function getSiteConfig() {
    const host = window.location.hostname;
    const path = window.location.pathname;
    if (host.includes('comic.naver.com')) {
      if (!path.includes('/detail')) return null;
      return { selector: 'img', minWidth: 500, minHeight: 300, isMangaSite: true };
    }
    if (host.includes('webtoon.kakao.com'))
      return { selector: 'img', minWidth: 500, minHeight: 300, isMangaSite: true };
    if (host.includes('webtoons.com')) {
      if (!path.includes('/viewer') && !path.includes('/episode') && !document.querySelector('._images')) return null;
      return { selector: 'img._images, img[class*="page"], img[data-url]', minWidth: 700, minHeight: 300, isMangaSite: true };
    }
    if (host.includes('mangadex.org'))
      return { selector: 'img.page-img, img[class*="page"], .reader-images img', minWidth: 400, minHeight: 300, isMangaSite: true };
    if (host.includes('viz.com'))
      return { selector: 'img.chapter-page, img[class*="manga"]', minWidth: 400, minHeight: 300, isMangaSite: true };
    if (host.includes('tapas.io'))
      return { selector: 'img.content-img, img[class*="episode"]', minWidth: 400, minHeight: 300, isMangaSite: true };

    // Raw/unofficial manga sites
    if (host.includes('manhwa-raw') || host.includes('manga-raw') ||
        host.includes('rawkuma') || host.includes('rawdevart') ||
        host.includes('manhwaclan') || host.includes('manhwatop') ||
        host.includes('manhuafast') || host.includes('manhuascan') ||
        host.includes('readmanhwa') || host.includes('toonily') ||
        host.includes('bato.to') || host.includes('manganato') ||
        host.includes('mangakakalot') || host.includes('chapmanganato'))
      return { selector: 'img', minWidth: 300, minHeight: 200, isMangaSite: true };

    // Generic fallback — works on any site not listed above
    return { selector: 'img', minWidth: 300, minHeight: 200, isMangaSite: false };
  }

  const siteConfig = getSiteConfig();
  if (!siteConfig) return;

  // ── State ──────────────────────────────────────────────────────────────────
  let autoTranslate = false;
  chrome.storage.local.get({ autoTranslate: false }, r => { autoTranslate = r.autoTranslate; });
  chrome.storage.onChanged.addListener(changes => {
    if (changes.autoTranslate) autoTranslate = changes.autoTranslate.newValue;
  });

  // ── Helpers ────────────────────────────────────────────────────────────────
  function isMangaPanel(img) {
    if (!img.complete || !img.naturalWidth) return false;
    if (img.naturalWidth  < siteConfig.minWidth)  return false;
    if (img.naturalHeight < siteConfig.minHeight) return false;
    if (img.offsetWidth < 150 || img.offsetHeight < 150) return false;
    const r = img.naturalWidth / img.naturalHeight;
    if (r < 0.1 || r > 8.0) return false;
    if (!img.src || !img.src.startsWith('http')) return false;
    if (img.dataset.mangaBtnAttached) return false;
    return true;
  }

  function escHtml(s) {
    if (!s) return '';
    return s.replace(/&/g,'&amp;').replace(/</g,'&lt;').replace(/>/g,'&gt;').replace(/"/g,'&quot;');
  }

  function getOrCreateWrapper(img) {
    if (img.parentElement?.classList.contains('ml-wrapper')) return img.parentElement;
    const w = document.createElement('div');
    w.className = 'ml-wrapper';
    w.style.cssText = 'position:relative;display:inline-block;line-height:0;';
    img.parentElement.insertBefore(w, img);
    w.appendChild(img);
    return w;
  }

  // ── Button attachment ──────────────────────────────────────────────────────
  function attachButton(img) {
    if (img.dataset.mangaBtnAttached) return;
    img.dataset.mangaBtnAttached = 'true';

    const wrapper = getOrCreateWrapper(img);
    const btn     = document.createElement('button');
    btn.className    = 'ml-btn';
    btn.textContent  = '🌐 Translate';
    wrapper.appendChild(btn);

    // Auto-translate badge
    const badge     = document.createElement('span');
    badge.className = 'ml-auto-badge';
    badge.textContent = '⚡ Auto';
    badge.style.display = 'none';
    wrapper.appendChild(badge);

    wrapper.addEventListener('mouseenter', () => { if (!btn.disabled) btn.style.opacity = '1'; });
    wrapper.addEventListener('mouseleave', () => { if (!btn.disabled) btn.style.opacity = '0'; });
    btn.addEventListener('click', async (e) => {
      e.stopPropagation();
      e.preventDefault();
      delete img.dataset.mangaAutoQueued;
      await handleTranslate(img, btn, badge);
    });

    // Register with auto-scroll observer
    scrollObserver.observe(wrapper);
  }

  // ── Translation handler ────────────────────────────────────────────────────
  // ── Multi-section capture ─────────────────────────────────────────────────
  // Splits tall panels into viewport-sized slices, translates each, remaps y_pct.

  async function captureFullPanel(img, targetLanguage, dpr, btn) {
    const vpW = window.innerWidth;
    const vpH = window.innerHeight;

    // Scroll panel top into view, then record its ABSOLUTE scroll position
    img.scrollIntoView({ behavior: 'instant', block: 'start' });
    await new Promise(r => setTimeout(r, 350));

    const rect0 = img.getBoundingClientRect();
    // Absolute Y of the panel top on the page (pixels from document top)
    const panelAbsTop = window.scrollY + rect0.top;
    const panelH      = rect0.height; // full CSS height of img

    const sliceStep  = Math.floor(vpH * 0.80); // advance 80% per section
    const numSlices  = Math.ceil(panelH / sliceStep);
    const allTranslations = [];

    console.log(`[MangaLens] Panel ${Math.round(panelH)}px, viewport ${Math.round(vpH)}px → ${numSlices} section(s), panelAbsTop=${Math.round(panelAbsTop)}`);

    for (let s = 0; s < numSlices; s++) {
      if (btn) btn.textContent = numSlices > 1 ? `⏳ ${s+1}/${numSlices}…` : '⏳ Translating…';

      // Scroll so this section's slice of the panel aligns with viewport top
      const targetScroll = panelAbsTop + (s * sliceStep) - 10;
      window.scrollTo({ top: Math.max(0, targetScroll), behavior: 'instant' });
      await new Promise(r => setTimeout(r, 400));

      // Re-measure after scroll
      const rect      = img.getBoundingClientRect();
      const visTop    = Math.max(0, rect.top);
      const visBottom = Math.min(vpH, rect.bottom);

      console.log(`[MangaLens] Section ${s}: rect.top=${Math.round(rect.top)}, visible=${Math.round(visTop)}→${Math.round(visBottom)}`);

      if (visBottom - visTop < 50) {
        console.warn(`[MangaLens] Section ${s} skipped — not enough visible`);
        continue;
      }

      // Pixel coords for captureVisibleTab
      const capX = Math.max(0, Math.round(rect.left * dpr));
      const capY = Math.max(0, Math.round(visTop  * dpr));
      const capW = Math.max(1, Math.min(Math.round(rect.width * dpr), Math.round(vpW * dpr) - capX));
      const capH = Math.max(1, Math.round((visBottom - visTop) * dpr));

      const cacheKey = numSlices > 1 ? `${img.src}__s${s}` : img.src;

      // Update button to show which section is being sent to AI
      if (btn) btn.textContent = numSlices > 1
        ? `🤖 AI processing ${s+1}/${numSlices}…`
        : '🤖 AI processing…';

      let resp;
      try {
        resp = await chrome.runtime.sendMessage({
          action: 'translatePanel',
          imageUrl: cacheKey,
          targetLanguage,
          rect: { x: capX, y: capY, width: capW, height: capH }
        });
      } catch (e) {
        console.error(`[MangaLens] Section ${s} sendMessage error:`, e);
        continue;
      }

      if (!resp?.success || !resp.translations?.length) {
        console.warn(`[MangaLens] Section ${s}: ${resp?.error || '0 translations'}`);
        continue;
      }

      console.log(`[MangaLens] Section ${s}: ${resp.translations.length} translation(s)`);

      // Remap y_pct from section-relative → full-panel-relative
      // visTop and rect.top are both viewport-relative at current scroll position
      const panelTopInViewport = rect.top; // may be negative if panel top scrolled above
      const visTopFromPanelTop    = (visTop    - panelTopInViewport) / panelH;
      const visBottomFromPanelTop = (visBottom - panelTopInViewport) / panelH;
      const visFrac               = visBottomFromPanelTop - visTopFromPanelTop;

      for (const t of resp.translations) {
        allTranslations.push({
          ...t,
          y_pct: Math.min(99, Math.max(1, (visTopFromPanelTop + (t.y_pct / 100) * visFrac) * 100))
        });
      }
    }

    console.log(`[MangaLens] Total: ${allTranslations.length} translations`);

    // Deduplicate by text only
    const seen = new Set();
    return allTranslations.filter(t => {
      const key = (t.original || '').trim().toLowerCase();
      if (!key) return true;
      if (seen.has(key)) return false;
      seen.add(key);
      return true;
    });
  }

    async function handleTranslate(img, btn, badge, isAuto = false) {
    if (btn.disabled) return;
    btn.disabled    = true;
    btn.textContent = '⏳ Capturing…';
    btn.style.opacity = '1';
    if (isAuto && badge) { badge.style.display = 'inline-block'; }

    try {
      const { targetLanguage } = await chrome.storage.local.get({ targetLanguage: 'English' });
      const dpr = window.devicePixelRatio || 1;

      // Scroll into view and wait for render
      // Multi-section capture — handles panels taller than the viewport.
      // Each section is captured separately, translated, and y_pct remapped
      // to full-panel coordinates before rendering.
      const translations = await captureFullPanel(img, targetLanguage, dpr, btn);

      renderOverlay(img, translations);

      const count = translations?.length ?? 0;
      btn.textContent = `✅ ${count} bubble(s)`;
      setTimeout(() => {
        btn.textContent = '🔄 Re-translate';
        btn.disabled    = false;
        btn.style.opacity = '0';
        if (badge) badge.style.display = 'none';
      }, 2500);

    } catch (err) {
      console.error('[MangaLens] Error:', err);
      btn.textContent   = `❌ ${err.message.length > 28 ? 'See console' : err.message}`;
      btn.title         = err.message;
      btn.style.opacity = '1';
      if (badge) badge.style.display = 'none';
      setTimeout(() => {
        btn.textContent   = '🌐 Retry';
        btn.disabled      = false;
        btn.style.opacity = '0';
        btn.title         = '';
      }, 4000);
    }
  }

  // ── Overlay rendering ──────────────────────────────────────────────────────
  function renderOverlay(img, translations, bubbles) {
    const wrapper = img.parentElement; // ml-wrapper
    wrapper.querySelector('.ml-overlay')?.remove();

    const overlay       = document.createElement('div');
    overlay.className   = 'ml-overlay';
    overlay.style.cssText = `
      position:absolute;top:0;left:0;
      width:${img.offsetWidth}px;height:${img.offsetHeight}px;
      pointer-events:none;z-index:9999;
    `;

    if (!translations || !translations.length) {
      const b = document.createElement('div');
      b.className   = 'ml-bubble ml-type-narration';
      b.style.cssText = 'left:50%;top:8%;pointer-events:auto;';
      b.innerHTML   = '<div class="ml-translation">No text found — try Re-translate</div>';
      overlay.appendChild(b);
    } else {
      translations.forEach(t => {
        const b         = document.createElement('div');
        b.className     = `ml-bubble ml-type-${t.type || 'speech'}`;
        b.style.cssText = `
          left:${Math.min(Math.max(t.x_pct ?? 50, 4), 92)}%;
          top:${Math.min(Math.max(t.y_pct  ?? 30, 4), 92)}%;
          pointer-events:auto;
        `;
        b.innerHTML = `
          <div class="ml-translation">${escHtml(t.translation)}</div>
          ${t.original ? `<div class="ml-original">${escHtml(t.original)}</div>` : ''}
        `;
        overlay.appendChild(b);
      });
    }

    wrapper.appendChild(overlay);
  }

  // ── Auto-translate on scroll ───────────────────────────────────────────────
  // Uses IntersectionObserver — fires when panel is 60% visible in viewport
  const scrollObserver = new IntersectionObserver((entries) => {
    for (const entry of entries) {
      if (!autoTranslate) continue;
      if (entry.intersectionRatio < 0.60) continue;

      const wrapper = entry.target;
      const img     = wrapper.querySelector('img');
      const btn     = wrapper.querySelector('.ml-btn');
      const badge   = wrapper.querySelector('.ml-auto-badge');

      if (!img || !btn || btn.disabled) continue;
      if (img.dataset.mangaAutoQueued) continue;
      img.dataset.mangaAutoQueued = 'true';

      // Small delay so user can see the panel before we fire
      setTimeout(() => handleTranslate(img, btn, badge, true), 600);
    }
  }, {
    threshold: [0.60],
    rootMargin: '0px'
  });

  // ── FAB (Translate page button) ────────────────────────────────────────────
  function injectFAB() {
    if (document.getElementById('ml-fab-wrap')) return;

    const wrap           = document.createElement('div');
    wrap.id              = 'ml-fab-wrap';
    wrap.style.cssText   = `
      position:fixed;bottom:24px;right:24px;z-index:99999;
      display:flex;flex-direction:column;align-items:flex-end;gap:8px;
    `;

    // Auto-translate toggle
    const toggleWrap           = document.createElement('label');
    toggleWrap.className       = 'ml-toggle-wrap';
    toggleWrap.style.cssText   = `
      display:flex;align-items:center;gap:7px;cursor:pointer;
      background:rgba(20,20,25,0.85);backdrop-filter:blur(8px);
      border:1px solid rgba(255,255,255,0.1);
      border-radius:20px;padding:5px 12px 5px 8px;
      font-size:12px;font-weight:600;color:#ccc;
      font-family:-apple-system,BlinkMacSystemFont,sans-serif;
      user-select:none;
    `;

    const toggleInput          = document.createElement('input');
    toggleInput.type           = 'checkbox';
    toggleInput.id             = 'ml-auto-toggle';
    toggleInput.style.cssText  = 'width:0;height:0;opacity:0;position:absolute;';
    toggleInput.checked        = autoTranslate;

    const toggleTrack          = document.createElement('div');
    toggleTrack.className      = 'ml-track';
    toggleTrack.style.cssText  = `
      width:28px;height:16px;border-radius:8px;
      background:${autoTranslate ? '#6B2CF5' : '#444'};
      position:relative;transition:background 0.2s;flex-shrink:0;
    `;

    const toggleThumb          = document.createElement('div');
    toggleThumb.style.cssText  = `
      position:absolute;top:2px;
      left:${autoTranslate ? '14px' : '2px'};
      width:12px;height:12px;border-radius:50%;background:#fff;
      transition:left 0.2s;
    `;
    toggleTrack.appendChild(toggleThumb);

    toggleWrap.appendChild(toggleInput);
    toggleWrap.appendChild(toggleTrack);
    toggleWrap.appendChild(document.createTextNode('⚡ Auto-translate'));

    toggleInput.addEventListener('change', async () => {
      autoTranslate = toggleInput.checked;
      await chrome.storage.local.set({ autoTranslate });
      toggleTrack.style.background = autoTranslate ? '#6B2CF5' : '#444';
      toggleThumb.style.left       = autoTranslate ? '14px' : '2px';
    });

    // Main FAB button
    const fab           = document.createElement('button');
    fab.id              = 'ml-fab';
    fab.textContent     = '🌐 Translate page';
    fab.style.cssText   = `
      background:#6B2CF5;color:white;border:none;border-radius:24px;
      padding:10px 20px;font-size:14px;font-weight:600;
      font-family:-apple-system,BlinkMacSystemFont,sans-serif;
      cursor:pointer;box-shadow:0 4px 16px rgba(107,44,245,0.35);
      transition:background 0.15s;white-space:nowrap;
    `;
    fab.addEventListener('mouseenter', () => fab.style.background = '#5621D4');
    fab.addEventListener('mouseleave', () => fab.style.background = '#6B2CF5');

    fab.addEventListener('click', async () => {
      if (fab.disabled) return;

      // Scan for all panels first
      scan();
      await new Promise(r => setTimeout(r, 150));

      const imgs = [...document.querySelectorAll(siteConfig.selector)]
        .filter(el => el.tagName === 'IMG' && el.complete && el.naturalWidth >= siteConfig.minWidth);

      const btns = imgs
        .map(img => ({ img, btn: img.parentElement?.querySelector('.ml-btn'), badge: img.parentElement?.querySelector('.ml-auto-badge') }))
        .filter(({ btn }) => btn && !btn.disabled);

      if (!btns.length) {
        fab.textContent = '🌐 No panels found';
        setTimeout(() => { fab.textContent = '🌐 Translate page'; }, 3000);
        return;
      }

      fab.disabled = true;

      // IMPORTANT: await each panel fully before starting the next.
      // captureFullPanel scrolls the page per section — concurrent calls
      // fight over the scroll position and captureVisibleTab, breaking everything.
      for (let i = 0; i < btns.length; i++) {
        const { img, btn, badge } = btns[i];
        if (btn.disabled) continue; // already translating
        fab.textContent = `⏳ Panel ${i + 1} / ${btns.length}…`;
        await handleTranslate(img, btn, badge);
      }

      fab.textContent = `✅ Done — ${btns.length} panels`;
      fab.disabled    = false;
      setTimeout(() => { fab.textContent = '🌐 Translate page'; }, 3000);
    });

    wrap.appendChild(toggleWrap);
    wrap.appendChild(fab);
    document.body.appendChild(wrap);
  }

  // ── Scan & init ────────────────────────────────────────────────────────────
  function scan() {
    document.querySelectorAll(siteConfig.selector).forEach(el => {
      if (el.tagName === 'IMG' && isMangaPanel(el)) attachButton(el);
    });
  }

  scan();
  injectFAB();

  const mutObs = new MutationObserver(() => requestAnimationFrame(scan));
  mutObs.observe(document.body, { childList: true, subtree: true });
  document.addEventListener('load', e => { if (e.target.tagName === 'IMG') requestAnimationFrame(scan); }, true);

  chrome.runtime.onMessage.addListener((msg, sender, sendResponse) => {
    if (msg.action === 'translateAll') {
      const panels = [...document.querySelectorAll(siteConfig.selector)]
        .filter(el => el.tagName === 'IMG' && el.complete && el.naturalWidth > 0);
      // Run sequentially — concurrent captureFullPanel calls break scroll position
      (async () => {
        for (const img of panels) {
          const btn   = img.parentElement?.querySelector('.ml-btn');
          const badge = img.parentElement?.querySelector('.ml-auto-badge');
          if (btn && !btn.disabled) await handleTranslate(img, btn, badge);
        }
      })();
      sendResponse({ count: panels.length });
    }
  });

  console.log('[MangaLens] v7 ready on', window.location.hostname);
})();
