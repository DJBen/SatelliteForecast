/*
 * Live "next pass" peek. Runs entirely in the browser:
 * public TLEs come from /api/orbital (a Hosting rewrite to the orbital_data
 * Cloud Function), propagation uses satellite.js, and the observer location is a
 * city the visitor picks or the browser's geolocation after a tap. Nothing about
 * the visitor is sent to the server.
 *
 * A pass counts as visible while the satellite is above 10°, sunlit, and the
 * observer's Sun is below -6° (civil twilight), matching the app's rule.
 */
(function () {
  'use strict';
  var S = window.satellite;
  var root = document.getElementById('peek');
  if (!root || !S) return;

  var DEG = Math.PI / 180, RAD = 180 / Math.PI;
  var EARTH_R = 6371, AU = 149597870.7;
  var STATIONS = [
    { id: '25544', name: 'International Space Station', short: 'ISS', chip: '' },
    { id: '48274', name: 'Tiangong', short: 'Tiangong', chip: 'warm' }
  ];
  var CITIES = [
    { n: 'Seattle', lat: 47.61, lon: -122.33, tz: 'America/Los_Angeles' },
    { n: 'San Francisco', lat: 37.77, lon: -122.42, tz: 'America/Los_Angeles' },
    { n: 'Los Angeles', lat: 34.05, lon: -118.24, tz: 'America/Los_Angeles' },
    { n: 'Denver', lat: 39.74, lon: -104.99, tz: 'America/Denver' },
    { n: 'Chicago', lat: 41.88, lon: -87.63, tz: 'America/Chicago' },
    { n: 'New York', lat: 40.71, lon: -74.01, tz: 'America/New_York' },
    { n: 'Toronto', lat: 43.65, lon: -79.38, tz: 'America/Toronto' },
    { n: 'Mexico City', lat: 19.43, lon: -99.13, tz: 'America/Mexico_City' },
    { n: 'São Paulo', lat: -23.55, lon: -46.63, tz: 'America/Sao_Paulo' },
    { n: 'London', lat: 51.51, lon: -0.13, tz: 'Europe/London' },
    { n: 'Paris', lat: 48.86, lon: 2.35, tz: 'Europe/Paris' },
    { n: 'Berlin', lat: 52.52, lon: 13.41, tz: 'Europe/Berlin' },
    { n: 'Madrid', lat: 40.42, lon: -3.70, tz: 'Europe/Madrid' },
    { n: 'Moscow', lat: 55.76, lon: 37.62, tz: 'Europe/Moscow' },
    { n: 'Beijing', lat: 39.90, lon: 116.40, tz: 'Asia/Shanghai' },
    { n: 'Shanghai', lat: 31.23, lon: 121.47, tz: 'Asia/Shanghai' },
    { n: 'Seoul', lat: 37.57, lon: 126.98, tz: 'Asia/Seoul' },
    { n: 'Tokyo', lat: 35.68, lon: 139.69, tz: 'Asia/Tokyo' },
    { n: 'Singapore', lat: 1.35, lon: 103.82, tz: 'Asia/Singapore' },
    { n: 'Sydney', lat: -33.87, lon: 151.21, tz: 'Australia/Sydney' }
  ];

  var el = {
    place: document.getElementById('peek-city'),
    locate: document.getElementById('peek-locate'),
    live: document.getElementById('peek-live'),
    when: document.getElementById('peek-when'),
    sat: document.getElementById('peek-sat'),
    sub: document.getElementById('peek-sub'),
    arc: document.getElementById('arc'),
    row: document.getElementById('peek-row'),
    up: document.getElementById('peek-up'),
    tz: document.getElementById('peek-tz'),
    status: document.getElementById('peek-status')
  };

  // ---- Observer state ----
  var localTz = (Intl.DateTimeFormat().resolvedOptions().timeZone) || 'UTC';
  function defaultCity() {
    for (var i = 0; i < CITIES.length; i++) if (CITIES[i].tz === localTz) return CITIES[i];
    return CITIES[0];
  }
  var observer = null;
  try { observer = JSON.parse(localStorage.getItem('ssp.observer') || 'null'); } catch (e) { observer = null; }
  if (!observer || typeof observer.lat !== 'number') observer = cityObserver(defaultCity());
  function cityObserver(c) { return { name: c.n, lat: c.lat, lon: c.lon, tz: c.tz, kind: 'city' }; }
  function remember() { try { localStorage.setItem('ssp.observer', JSON.stringify(observer)); } catch (e) { /* private mode */ } }

  CITIES.forEach(function (c) {
    var o = document.createElement('option'); o.value = c.n; o.textContent = c.n; el.place.appendChild(o);
  });
  var mine = document.createElement('option'); mine.value = '__me'; mine.textContent = 'Your location'; mine.hidden = true; el.place.appendChild(mine);
  function syncSelect() {
    if (observer.kind === 'me') { mine.hidden = false; el.place.value = '__me'; }
    else el.place.value = observer.name;
  }
  el.place.addEventListener('change', function () {
    var c = CITIES.filter(function (x) { return x.n === el.place.value; })[0];
    if (!c) return;
    observer = cityObserver(c); remember(); run();
  });
  el.locate.addEventListener('click', function () {
    if (!navigator.geolocation) { note('This browser does not offer location.'); return; }
    el.locate.disabled = true; el.locate.textContent = 'Locating…';
    navigator.geolocation.getCurrentPosition(function (pos) {
      observer = { name: 'Your location', lat: pos.coords.latitude, lon: pos.coords.longitude, tz: localTz, kind: 'me' };
      remember(); el.locate.disabled = false; el.locate.textContent = 'Use my location'; run();
    }, function () {
      el.locate.disabled = false; el.locate.textContent = 'Use my location';
      note('Location was not shared. Pick a city instead.');
    }, { maximumAge: 600000, timeout: 12000 });
  });

  // ---- Astronomy helpers ----
  function sunEci(date) {
    // Low-precision solar position (Astronomical Almanac), good to ~0.01°.
    var n = date.getTime() / 86400000 + 2440587.5 - 2451545.0;
    var L = ((280.460 + 0.9856474 * n) % 360 + 360) % 360;
    var g = ((357.528 + 0.9856003 * n) % 360 + 360) % 360 * DEG;
    var lam = (L + 1.915 * Math.sin(g) + 0.020 * Math.sin(2 * g)) * DEG;
    var eps = (23.439 - 0.0000004 * n) * DEG;
    var R = (1.00014 - 0.01671 * Math.cos(g) - 0.00014 * Math.cos(2 * g)) * AU;
    return { x: R * Math.cos(lam), y: R * Math.cos(eps) * Math.sin(lam), z: R * Math.sin(eps) * Math.sin(lam) };
  }
  function sunlit(r, s) {
    // Cylindrical Earth shadow: behind Earth (r·ŝ < 0) and within one Earth radius of the axis.
    var sm = Math.sqrt(s.x * s.x + s.y * s.y + s.z * s.z);
    var ux = s.x / sm, uy = s.y / sm, uz = s.z / sm;
    var proj = r.x * ux + r.y * uy + r.z * uz;
    if (proj >= 0) return true;
    var px = r.x - proj * ux, py = r.y - proj * uy, pz = r.z - proj * uz;
    return Math.sqrt(px * px + py * py + pz * pz) > EARTH_R;
  }
  function parseTle(text) {
    var lines = text.split(/\r?\n/).map(function (l) { return l.trim(); }).filter(Boolean);
    for (var i = 0; i + 1 < lines.length; i++) {
      if (lines[i].charAt(0) === '1' && lines[i + 1].charAt(0) === '2') return [lines[i], lines[i + 1]];
    }
    throw new Error('No TLE in response');
  }

  // Sample a satellite from `start` for `days`, returning visible passes.
  function passes(station, tle, obs, start, days) {
    var satrec = S.twoline2satrec(tle[0], tle[1]);
    var gd = { latitude: obs.lat * DEG, longitude: obs.lon * DEG, height: 0 };
    var out = [], step = 10, pass = null;
    function sample(t) {
      var pv = S.propagate(satrec, t);
      if (!pv.position || typeof pv.position !== 'object') return null;
      var gmst = S.gstime(t);
      var look = S.ecfToLookAngles(gd, S.eciToEcf(pv.position, gmst));
      var sun = sunEci(t);
      var sunLook = S.ecfToLookAngles(gd, S.eciToEcf(sun, gmst));
      var elev = look.elevation * RAD, az = ((look.azimuth * RAD) % 360 + 360) % 360;
      return { t: t, el: elev, az: az, vis: elev >= 10 && sunLook.elevation * RAD < -6 && sunlit(pv.position, sun) };
    }
    var end = start.getTime() + days * 86400000;
    for (var ms = start.getTime(); ms < end; ms += step * 1000) {
      var p = sample(new Date(ms));
      if (!p) continue;
      if (p.el > 0) {
        if (!pass) pass = { station: station, samples: [] };
        pass.samples.push(p);
      } else if (pass) { finish(pass); pass = null; }
    }
    function finish(ps) {
      var s = ps.samples, vis = s.filter(function (x) { return x.vis; });
      if (vis.length < 6) return; // under a minute of visibility is not worth a trip outside
      var peak = s[0], visPeak = vis[0];
      s.forEach(function (x) { if (x.el > peak.el) peak = x; });
      vis.forEach(function (x) { if (x.el > visPeak.el) visPeak = x; });
      ps.rise = s[0]; ps.set = s[s.length - 1]; ps.peak = peak;
      ps.visStart = vis[0]; ps.visEnd = vis[vis.length - 1]; ps.visPeak = visPeak;
      ps.visible = ps.visStart.t.getTime() > Date.now() || ps.visEnd.t.getTime() > Date.now();
      // Refine the visible start to the second so the headline time is honest.
      var t0 = ps.visStart.t.getTime() - step * 1000;
      for (var ms2 = t0; ms2 <= ps.visStart.t.getTime(); ms2 += 1000) {
        var q = sample(new Date(ms2)); if (q && q.vis) { ps.visStart = q; break; }
      }
      out.push(ps);
    }
    return out;
  }

  // ---- Formatting ----
  var COMPASS = ['N', 'NNE', 'NE', 'ENE', 'E', 'ESE', 'SE', 'SSE', 'S', 'SSW', 'SW', 'WSW', 'W', 'WNW', 'NW', 'NNW'];
  function compass(az) { return COMPASS[Math.round(az / 22.5) % 16]; }
  function fmt(t, tz, opts) { try { return new Intl.DateTimeFormat(undefined, Object.assign({ timeZone: tz }, opts)).format(t); } catch (e) { return t.toLocaleTimeString(); } }
  function clock(t, tz) { return fmt(t, tz, { hour: 'numeric', minute: '2-digit' }); }
  function clockS(t, tz) { return fmt(t, tz, { hour: 'numeric', minute: '2-digit', second: '2-digit' }); }
  function dayKey(t, tz) { return fmt(t, tz, { year: 'numeric', month: '2-digit', day: '2-digit' }); }
  function dayLabel(t, tz) {
    var now = new Date(), today = dayKey(now, tz), tomorrow = dayKey(new Date(now.getTime() + 86400000), tz), k = dayKey(t, tz);
    var h = parseInt(fmt(t, tz, { hour: 'numeric', hour12: false }), 10);
    if (k === today) return h < 12 ? 'This morning' : 'Tonight';
    if (k === tomorrow) return 'Tomorrow';
    return fmt(t, tz, { weekday: 'long' });
  }
  function shortDay(t, tz) { var d = dayLabel(t, tz); return d === 'Tonight' || d === 'Tomorrow' ? d.toLowerCase() : d === 'This morning' ? 'this morning' : d; }
  function tzLabel(tz) { try { return new Intl.DateTimeFormat(undefined, { timeZone: tz, timeZoneName: 'short' }).formatToParts(new Date()).filter(function (p) { return p.type === 'timeZoneName'; })[0].value; } catch (e) { return tz; } }

  // ---- Arc, drawn to scale (elevation → height) from the actual samples ----
  function drawArc(ps) {
    var W = 520, H = 190, hy = 160, top = 24;
    var y = function (e) { return hy - (Math.max(e, 0) / 90) * (hy - top); };
    var s = ps.samples, t0 = s[0].t.getTime(), t1 = s[s.length - 1].t.getTime();
    var x = function (t) { return 40 + ((t.getTime() - t0) / (t1 - t0)) * (W - 80); };
    var pt = function (p) { return x(p.t).toFixed(1) + ',' + y(p.el).toFixed(1); };
    var before = s.filter(function (p) { return p.t <= ps.visStart.t; }).map(pt).join(' ');
    var during = s.filter(function (p) { return p.t >= ps.visStart.t && p.t <= ps.visEnd.t; }).map(pt).join(' ');
    var after = s.filter(function (p) { return p.t >= ps.visEnd.t; }).map(pt).join(' ');
    var peak = ps.visPeak;
    el.arc.innerHTML =
      '<defs><linearGradient id="g" x1="0" x2="0" y1="0" y2="1"><stop offset="0" stop-color="#3b2f63" stop-opacity=".55"/><stop offset="1" stop-color="#0a1120" stop-opacity="0"/></linearGradient></defs>' +
      '<path d="M0 ' + hy + ' Q ' + (W / 2) + ' ' + (hy - 26) + ' ' + W + ' ' + hy + ' L ' + W + ' ' + H + ' L 0 ' + H + ' Z" fill="url(#g)"/>' +
      '<path d="M0 ' + hy + ' Q ' + (W / 2) + ' ' + (hy - 26) + ' ' + W + ' ' + hy + '" fill="none" stroke="#5d6d88" stroke-width="1" stroke-dasharray="2 4"/>' +
      [10, 30, 60].map(function (e) { return '<line x1="40" x2="' + (W - 40) + '" y1="' + y(e) + '" y2="' + y(e) + '" stroke="#23324c" stroke-width="1"/><text x="' + (W - 36) + '" y="' + (y(e) + 4) + '" fill="#5d6d88" font-size="10" font-family="IBM Plex Mono, monospace">' + e + '°</text>'; }).join('') +
      '<polyline points="' + before + '" fill="none" stroke="#6fe3d2" stroke-width="2" stroke-dasharray="3 6" stroke-linecap="round" opacity=".6"/>' +
      '<polyline points="' + during + '" fill="none" stroke="#6fe3d2" stroke-width="2.5" stroke-linecap="round"/>' +
      '<polyline points="' + after + '" fill="none" stroke="#6fe3d2" stroke-width="2" stroke-dasharray="3 6" stroke-linecap="round" opacity=".6"/>' +
      '<circle cx="' + x(ps.visEnd.t) + '" cy="' + y(ps.visEnd.el) + '" r="5" fill="#eaf0f8"/>' +
      '<circle cx="' + x(peak.t) + '" cy="' + y(peak.el) + '" r="3" fill="#6fe3d2"/>' +
      '<text x="' + x(peak.t) + '" y="' + (y(peak.el) - 10) + '" fill="#6fe3d2" text-anchor="middle" font-size="11" font-family="IBM Plex Mono, monospace">' + Math.round(peak.el) + '° highest</text>' +
      '<text x="40" y="' + (hy + 18) + '" fill="#8fa0b8" font-size="11" font-family="IBM Plex Mono, monospace">' + compass(ps.rise.az) + '</text>' +
      '<text x="' + (W - 40) + '" y="' + (hy + 18) + '" fill="#8fa0b8" text-anchor="end" font-size="11" font-family="IBM Plex Mono, monospace">' + compass(ps.set.az) + '</text>';
  }

  function note(msg) { el.status.textContent = msg; el.status.hidden = !msg; }
  function setLive(on, label) { el.live.classList.toggle('off', !on); el.live.lastChild.textContent = label; }

  function render(all) {
    var tz = observer.tz;
    all.sort(function (a, b) { return a.visStart.t - b.visStart.t; });
    var next = all[0];
    if (!next) {
      el.when.textContent = 'No visible pass in the next 7 days';
      el.sat.textContent = 'from ' + observer.name;
      el.sub.textContent = 'Visible passes come in cycles. The app will remind you when the next window opens.';
      el.arc.innerHTML = ''; el.row.innerHTML = ''; el.up.innerHTML = '';
      return;
    }
    var minutes = Math.max(1, Math.round((next.visEnd.t - next.visStart.t) / 60000));
    el.when.innerHTML = dayLabel(next.visStart.t, tz) + ' <span class="mono">' + clock(next.visStart.t, tz) + '</span>';
    el.sat.textContent = next.station.name;
    el.sub.textContent = 'Visible ' + minutes + ' min · ' + compass(next.visStart.az) + ' to ' + compass(next.visEnd.az) + ' · ' + Math.round(next.visPeak.el) + '° at highest';
    drawArc(next);
    el.row.innerHTML =
      '<div>Appears<b>' + clockS(next.visStart.t, tz) + ' · ' + Math.round(next.visStart.az) + '°</b></div>' +
      '<div>Highest<b>' + clockS(next.visPeak.t, tz) + ' · ' + Math.round(next.visPeak.el) + '°</b></div>' +
      '<div>Disappears<b>' + clockS(next.visEnd.t, tz) + ' · ' + Math.round(next.visEnd.az) + '°</b></div>';
    el.up.innerHTML = all.slice(1, 3).map(function (p) {
      return '<span><b>' + p.station.short + '</b> <span class="chip ' + p.station.chip + '">' + Math.round(p.visPeak.el) + '°</span> ' +
        shortDay(p.visStart.t, tz) + ' ' + clock(p.visStart.t, tz) + '</span>';
    }).join('');
    el.tz.textContent = 'Times in ' + tzLabel(tz);
  }

  var tleCache = null;
  function loadTles() {
    if (tleCache) return Promise.resolve(tleCache);
    return Promise.all(STATIONS.map(function (st) {
      return fetch('/api/orbital?category=' + st.id, { cache: 'default' }).then(function (r) {
        if (!r.ok) throw new Error('orbital ' + r.status);
        return r.text();
      }).then(parseTle);
    })).then(function (tles) { tleCache = tles; return tles; });
  }

  function run() {
    syncSelect(); note(''); root.classList.add('busy'); setLive(true, 'Computing');
    loadTles().then(function (tles) {
      var now = new Date(), all = [];
      STATIONS.forEach(function (st, i) {
        passes(st, tles[i], observer, now, 7).forEach(function (p) { if (p.visEnd.t > now) all.push(p); });
      });
      render(all); setLive(true, 'Live'); root.classList.remove('busy');
    }).catch(function (err) {
      root.classList.remove('busy'); setLive(false, 'Offline');
      note('Orbital data is unavailable right now. The app keeps its own copy, so passes there still work.');
      if (window.console) console.warn(err);
    });
  }
  run();
})();
