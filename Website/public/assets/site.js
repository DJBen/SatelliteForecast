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

  // ---- Star field ----
  var c = document.getElementById('stars');
  if (c) {
    var ctx = c.getContext('2d');
    var seed = function () {
      var dpr = Math.min(window.devicePixelRatio || 1, 2);
      c.width = innerWidth * dpr; c.height = innerHeight * dpr; ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
      var n = Math.floor(innerWidth * innerHeight / 3800);
      ctx.clearRect(0, 0, innerWidth, innerHeight);
      for (var i = 0; i < n; i++) {
        var r = Math.random() * 1.1 + 0.2, a = Math.random() * 0.5 + 0.15, warm = Math.random() < 0.08;
        ctx.beginPath(); ctx.arc(Math.random() * innerWidth, Math.random() * innerHeight, r, 0, Math.PI * 2);
        ctx.fillStyle = warm ? 'rgba(240,161,132,' + a + ')' : 'rgba(236,238,242,' + a + ')';
        ctx.fill();
      }
    };
    seed(); window.addEventListener('resize', seed);
  }

  // ---- Showcase: the step nearest the viewport middle drives the pinned phone ----
  var frames = document.querySelectorAll('#frames img'), dots = document.querySelectorAll('#chips button'), steps = document.querySelectorAll('#steps .step');
  if (steps.length) {
    var current = 0, lock = 0, ticking = false;
    var narrow = function () { return innerWidth <= 860; };
    var setFrame = function (i) {
      if (i === current) return; current = i;
      frames.forEach(function (f) { f.classList.toggle('on', +f.dataset.i === i); });
      dots.forEach(function (d) { d.classList.toggle('on', +d.dataset.i === i); d.setAttribute('aria-selected', +d.dataset.i === i); });
      steps.forEach(function (st) { st.classList.toggle('on', +st.dataset.i === i); });
    };
    var nearest = function () {
      if (lock > Date.now()) return;
      var best = 0, bestD = Infinity;
      steps.forEach(function (st, i) {
        // On narrow screens the phone pins to the top, so judge steps against the lower part of the viewport.
        var r = st.getBoundingClientRect(), ref = narrow() ? innerHeight * 0.72 : innerHeight / 2;
        var d = Math.abs((r.top + r.bottom) / 2 - ref);
        if (d < bestD) { bestD = d; best = i; }
      });
      setFrame(best);
    };
    var onScroll = function () { if (!ticking) { ticking = true; requestAnimationFrame(function () { nearest(); ticking = false; }); } };
    window.addEventListener('scroll', onScroll, { passive: true });
    document.getElementById('steps').addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('resize', onScroll);
    var goTo = function (i) {
      setFrame(i); lock = Date.now() + 700;
      var st = steps[i];
      var top = st.getBoundingClientRect().top + scrollY - (narrow() ? innerHeight * 0.5 : (innerHeight - st.offsetHeight) / 2);
      window.scrollTo({ top: top, behavior: 'smooth' });
    };
    dots.forEach(function (d) { d.addEventListener('click', function () { goTo(+d.dataset.i); }); });
    steps.forEach(function (st) { st.addEventListener('click', function () { goTo(+st.dataset.i); }); });
    nearest();
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
