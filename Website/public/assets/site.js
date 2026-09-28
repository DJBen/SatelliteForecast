(function () {
  'use strict';

  // ---- App Store banner: Safari on iOS renders the native Smart App Banner from the
  // apple-itunes-app meta tag, so ours shows everywhere else until dismissed. ----
  var store = document.getElementById('store');
  if (store) {
    var ua = navigator.userAgent, iOS = /iPhone|iPad|iPod/.test(ua) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1);
    var safari = /Safari/.test(ua) && !/CriOS|FxiOS|EdgiOS|OPiOS|DuckDuckGo/.test(ua);
    var dismissed = false;
    try { dismissed = localStorage.getItem('ssp.store') === '1'; } catch (e) { dismissed = false; }
    if (!(iOS && safari) && !dismissed) store.hidden = false;
    document.getElementById('store-x').addEventListener('click', function () {
      store.hidden = true;
      try { localStorage.setItem('ssp.store', '1'); } catch (e) { /* ignore */ }
    });
  }

  var reduce = matchMedia('(prefers-reduced-motion: reduce)').matches;

  // ---- Star field: slow twinkle, paused when the tab is hidden ----
  var c = document.getElementById('stars');
  if (c) {
    var ctx = c.getContext('2d'), stars = [], W = 0, H = 0;
    var seed = function () {
      var dpr = Math.min(window.devicePixelRatio || 1, 2);
      W = innerWidth; H = innerHeight; c.width = W * dpr; c.height = H * dpr; ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      stars = [];
      var n = Math.floor(W * H / 3800);
      for (var i = 0; i < n; i++) stars.push({ x: Math.random() * W, y: Math.random() * H, r: Math.random() * 1.1 + 0.2, a: Math.random() * 0.5 + 0.15, w: Math.random() < 0.08, ph: Math.random() * 6.28, sp: 0.4 + Math.random() * 1.2 });
      paint(0);
    };
    var paint = function (t) {
      ctx.clearRect(0, 0, W, H);
      for (var i = 0; i < stars.length; i++) {
        var s = stars[i], a = s.a * (0.75 + 0.25 * Math.sin(s.ph + t * 0.001 * s.sp));
        ctx.beginPath(); ctx.arc(s.x, s.y, s.r, 0, 6.2832);
        ctx.fillStyle = (s.w ? 'rgba(240,161,132,' : 'rgba(236,238,242,') + a.toFixed(3) + ')';
        ctx.fill();
      }
    };
    var loop = function (t) { if (!document.hidden) paint(t); requestAnimationFrame(loop); };
    seed(); window.addEventListener('resize', seed);
    if (!reduce) requestAnimationFrame(loop);
  }

  // ---- Showcase carousel: scroll progress through the tall section drives the slides ----
  var section = document.getElementById('features'), stage = document.getElementById('stage');
  if (section && stage) {
    var slides = document.querySelectorAll('#track .slide'), caps = document.querySelectorAll('#captions .cap'), chips = document.querySelectorAll('#chips button');
    var N = slides.length, current = -1, ticking = false, p = 0, target = null;
    var bar = document.createElement('div'); bar.className = 'progress'; bar.innerHTML = '<i></i>'; stage.appendChild(bar);
    var barFill = bar.firstChild;
    var progress = function () {
      var r = section.getBoundingClientRect(), range = section.offsetHeight - innerHeight;
      return Math.min(1, Math.max(0, -r.top / range)) * (N - 1);
    };
    var layout = function () {
      var slot = slides[0].offsetWidth + (innerWidth <= 860 ? 14 : 36);
      for (var i = 0; i < N; i++) {
        var d = i - p, ad = Math.abs(d);
        var x = d * slot, sc = Math.max(0.72, 1 - 0.14 * ad), op = Math.max(0, 1 - 0.38 * ad), ry = Math.max(-28, Math.min(28, -d * 16));
        slides[i].style.transform = 'translate(-50%, -50%) translateX(' + x.toFixed(1) + 'px) scale(' + sc.toFixed(3) + ') rotateY(' + ry.toFixed(1) + 'deg)';
        slides[i].style.opacity = op.toFixed(3);
        slides[i].style.zIndex = String(10 - Math.round(ad * 2));
      }
      var idx = Math.round(p);
      if (idx !== current) {
        current = idx;
        slides.forEach(function (el, i) { el.classList.toggle('on', i === idx); });
        caps.forEach(function (el, i) { el.classList.toggle('on', i === idx); });
        chips.forEach(function (el, i) { el.classList.toggle('on', i === idx); el.setAttribute('aria-selected', i === idx); });
      }
      barFill.style.transform = 'translateX(' + (p / (N - 1) * 300).toFixed(1) + '%)';
    };
    var update = function () {
      var goal = progress();
      p = reduce ? goal : p + (goal - p) * 0.18; // ease toward the scroll position
      layout();
      if (Math.abs(goal - p) > 0.002) requestAnimationFrame(update); else { p = goal; layout(); ticking = false; }
    };
    var onScroll = function () { if (!ticking) { ticking = true; requestAnimationFrame(update); } };
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    chips.forEach(function (ch, i) {
      ch.addEventListener('click', function () {
        var range = section.offsetHeight - innerHeight, top = section.getBoundingClientRect().top + scrollY;
        window.scrollTo({ top: top + range * (i / (N - 1)), behavior: reduce ? 'auto' : 'smooth' });
      });
    });
    slides.forEach(function (sl, i) { sl.addEventListener('click', function () { chips[i].click(); }); });
    p = progress(); layout();
  }

  // ---- Copy address ----
  var btn = document.getElementById('copy-mail');
  if (btn) {
    btn.addEventListener('click', function () {
      var el = document.getElementById('mail'), txt = el.textContent;
      var done = function () { btn.textContent = 'Copied'; setTimeout(function () { btn.textContent = 'Copy address'; }, 1600); };
      var fallback = function () {
        var r = document.createRange(); r.selectNodeContents(el);
        var s = getSelection(); s.removeAllRanges(); s.addRange(r); btn.textContent = 'Selected';
      };
      try { navigator.clipboard.writeText(txt).then(done, fallback); } catch (err) { fallback(); }
    });
  }
})();
