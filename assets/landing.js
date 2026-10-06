/* Standalone landing interactions. The application and authentication stay in index.html. */
(() => {
  'use strict';
  // Keep this deadline aligned with PROMO_END_AT in app.js and the server promotion.
  const offer = document.querySelector('[data-promo-end]');
  if (offer) {
    const end = Date.parse(offer.dataset.promoEnd);
    const digits = offer.querySelector('.welcome-countdown-digits');
    const status = document.getElementById('welcome-promo-status');
    let promoInterval;
    function updatePromoCountdown() {
      const remaining = Number.isFinite(end) ? Math.max(0, Math.ceil((end - Date.now()) / 1000)) : 0;
      if (remaining === 0) {
        digits.hidden = true;
        offer.classList.add('promo-ended');
        const message = Number.isFinite(end) ? 'โปรโมชั่นสิ้นสุดแล้ว' : 'ดูแพ็กเกจการใช้งาน';
        status.textContent = message;
        offer.querySelector('.welcome-offer-copy h3').textContent = message;
        offer.setAttribute('aria-label', message);
        clearInterval(promoInterval);
        return false;
      }
      status.textContent = 'โปรโมชั่นจะสิ้นสุดใน';
      digits.hidden = false;
      const values = { days: Math.floor(remaining / 86400), hours: Math.floor(remaining / 3600) % 24, minutes: Math.floor(remaining / 60) % 60, seconds: remaining % 60 };
      Object.entries(values).forEach(([unit, value]) => {
        offer.querySelector('[data-promo-unit="' + unit + '"]').textContent = String(value).padStart(2, '0');
      });
      return true;
    }
    if (updatePromoCountdown()) promoInterval = setInterval(updatePromoCountdown, 1000);
    document.addEventListener('visibilitychange', () => { if (!document.hidden) updatePromoCountdown(); });
  }

  const pins = [...document.querySelectorAll('.monster-pin')];
  let activePin = null;
  function placePinInfo(pin) {
    if (!pin || activePin !== pin) return;
    const info = document.getElementById(pin.getAttribute('aria-controls'));
    info.style.setProperty('--tooltip-shift', '0px');
    const bounds = document.getElementById('world').getBoundingClientRect();
    const rect = info.getBoundingClientRect();
    const leftEdge = Math.max(0, bounds.left) + 8;
    const rightEdge = Math.min(document.documentElement.clientWidth, bounds.right) - 8;
    const shift = rect.left < leftEdge ? leftEdge - rect.left : rect.right > rightEdge ? rightEdge - rect.right : 0;
    info.style.setProperty('--tooltip-shift', shift + 'px');
  }
  function closePin(pin) {
    if (!pin) return;
    pin.setAttribute('aria-expanded', 'false');
    document.getElementById(pin.getAttribute('aria-controls')).hidden = true;
    if (activePin === pin) activePin = null;
  }
  function openPin(pin) {
    if (activePin !== pin) closePin(activePin);
    pin.setAttribute('aria-expanded', 'true');
    document.getElementById(pin.getAttribute('aria-controls')).hidden = false;
    activePin = pin;
    requestAnimationFrame(() => placePinInfo(pin));
  }
  pins.forEach(pin => {
    pin.addEventListener('pointerenter', event => { if (event.pointerType === 'mouse') openPin(pin); });
    pin.addEventListener('pointerleave', event => { if (event.pointerType === 'mouse' && document.activeElement !== pin) closePin(pin); });
    pin.addEventListener('focus', () => openPin(pin));
    pin.addEventListener('blur', () => closePin(pin));
    pin.addEventListener('click', () => openPin(pin));
  });
  document.addEventListener('pointerdown', event => { if (!event.target.closest('.monster-pin')) closePin(activePin); });
  document.addEventListener('keydown', event => { if (event.key === 'Escape') closePin(activePin); });

  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  const motionButton = document.getElementById('motion-toggle');
  let paused = reducedMotion.matches;
  function renderMotion() {
    document.body.classList.toggle('motion-paused', paused);
    motionButton.setAttribute('aria-pressed', String(paused));
    motionButton.setAttribute('aria-label', paused ? 'เปิดการเคลื่อนไหวของตัวละคร' : 'หยุดการเคลื่อนไหวของตัวละคร');
    // The system preference always takes precedence over the optional animation.
    motionButton.disabled = reducedMotion.matches;
    motionButton.title = reducedMotion.matches ? 'ปิดการเคลื่อนไหวตามการตั้งค่าอุปกรณ์' : motionButton.getAttribute('aria-label');
  }
  motionButton.addEventListener('click', () => { paused = !paused; renderMotion(); });
  reducedMotion.addEventListener('change', () => { paused = reducedMotion.matches; renderMotion(); });
  renderMotion();

  const world = document.getElementById('world');
  const left = document.getElementById('pan-left');
  const right = document.getElementById('pan-right');
  function updatePanButtons() {
    left.disabled = world.scrollLeft <= 1;
    right.disabled = world.scrollLeft + world.clientWidth >= world.scrollWidth - 1;
  }
  function pan(direction) {
    world.scrollBy({ left: direction * world.clientWidth * .65, behavior: reducedMotion.matches ? 'instant' : 'smooth' });
  }
  left.addEventListener('click', () => pan(-1));
  right.addEventListener('click', () => pan(1));
  world.addEventListener('scroll', () => {
    updatePanButtons();
    placePinInfo(activePin);
  }, { passive: true });
  world.addEventListener('keydown', event => {
    if (event.target !== world || !['ArrowLeft', 'ArrowRight'].includes(event.key)) return;
    event.preventDefault();
    pan(event.key === 'ArrowLeft' ? -1 : 1);
  });
  function centerMobileMap() {
    if (window.innerWidth < 768) world.scrollLeft = (world.scrollWidth - world.clientWidth) * .7;
    updatePanButtons();
  }
  centerMobileMap();
  window.addEventListener('resize', updatePanButtons);

  const tabs = [...document.querySelectorAll('[role="tab"]')];
  function selectTab(tab, focus = false) {
    tabs.forEach(item => {
      const selected = item === tab;
      item.setAttribute('aria-selected', String(selected));
      item.tabIndex = selected ? 0 : -1;
      document.getElementById(item.getAttribute('aria-controls')).hidden = !selected;
    });
    if (focus) tab.focus();
  }
  tabs.forEach((tab, index) => {
    tab.addEventListener('click', () => selectTab(tab));
    tab.addEventListener('keydown', event => {
      if (event.altKey || event.ctrlKey || event.metaKey) return;
      let next;
      if (event.key === 'ArrowDown' || event.key === 'ArrowRight') next = (index + 1) % tabs.length;
      if (event.key === 'ArrowUp' || event.key === 'ArrowLeft') next = (index - 1 + tabs.length) % tabs.length;
      if (event.key === 'Home') next = 0;
      if (event.key === 'End') next = tabs.length - 1;
      if (next !== undefined) { event.preventDefault(); selectTab(tabs[next], true); }
    });
  });

  // ---------- นับผู้เข้าชมหน้าแรก → log_events (ตัวเดียวกับที่แอปใช้) → แดชบอร์ดแอดมิน ----------
  // ใช้รหัสสุ่มของเครื่องชุดเดียวกับแอป (localStorage gum100_vid) จึงตามได้ว่าคนที่เข้าหน้าแรกไปเข้าแอป/สมัครต่อไหม
  // ไม่เก็บข้อมูลส่วนตัว · เข้าหน้าแรก = นับครั้งเดียวต่อการเปิดเว็บ (แท็บ) · กดปุ่มไปแอป = นับว่ากดปุ่มไหน
  // ค่า URL/คีย์สาธารณะ (publishable) ชุดเดียวกับใน assets/app.js
  const SUPA_URL = 'https://jnwckkcjurchnppekhpc.supabase.co';
  const SUPA_KEY = 'sb_publishable_Z_xnoeSTMY2t-VqaDfPmKg_FfOCjTOf';
  function visitorId() {
    try {
      let vid = localStorage.getItem('gum100_vid');
      if (!vid || !/^[A-Za-z0-9-]{8,40}$/.test(vid)) {
        vid = (window.crypto && crypto.randomUUID) ? crypto.randomUUID() : (Date.now().toString(36) + '-' + Math.random().toString(36).slice(2, 12));
        localStorage.setItem('gum100_vid', vid);
      }
      return vid;
    } catch (e) { return null; }
  }
  // ประเภทอุปกรณ์แบบเดียวกับแอป: จอสัมผัส + ด้านสั้นของจอ < 600px = มือถือ, จอสัมผัสที่ใหญ่กว่านั้น = แท็บเล็ต
  function deviceType() {
    const coarse = !!(window.matchMedia && matchMedia('(pointer: coarse)').matches);
    const shortSide = Math.min(screen.width || 0, screen.height || 0) || Math.min(window.innerWidth, window.innerHeight);
    if (coarse && shortSide < 600) return 'mobile';
    return coarse ? 'tablet' : 'desktop';
  }
  function sendEvents(events) {
    const vid = visitorId();
    if (!vid) return;
    try {
      // keepalive: ส่งให้ถึงแม้กำลังเปลี่ยนไปหน้าแอป
      fetch(SUPA_URL + '/rest/v1/rpc/log_events', {
        method: 'POST', keepalive: true,
        headers: { apikey: SUPA_KEY, 'Content-Type': 'application/json' },
        body: JSON.stringify({ p_visitor: vid, p_events: events })
      }).catch(() => {});
    } catch (e) { /* นับไม่ได้ไม่เป็นไร หน้าเว็บทำงานต่อปกติ */ }
  }
  // แหล่งที่มาของการเข้าเว็บรอบนี้ — สคริปต์ส่วนหัวของ index.html หาไว้ให้แล้ว (window.__gum100Src / sessionStorage gum100_src)
  function trafficSource() {
    try { return window.__gum100Src || sessionStorage.getItem('gum100_src') || null; } catch (e) { return window.__gum100Src || null; }
  }
  try {
    if (!sessionStorage.getItem('gum100_landing')) {
      sessionStorage.setItem('gum100_landing', '1');
      sendEvents([{ e: 'landing_view', p: 'landing', m: deviceType(), s: trafficSource() }]);
    }
  } catch (e) { sendEvents([{ e: 'landing_view', p: 'landing', m: deviceType(), s: trafficSource() }]); }
  document.addEventListener('click', event => {
    const link = event.target.closest && event.target.closest('a[href^="app.html"]');
    if (!link) return;
    const href = link.getAttribute('href');
    const kind = /auth=register/.test(href) ? 'signup' : /auth=login/.test(href) ? 'login' : /#pricing/.test(href) ? 'pricing' : 'app';
    sendEvents([{ e: 'landing_cta', p: 'landing', m: kind }]);
  });
})();
