/* VicThree Defence CDS PYQ Library — identity, access tiers and the entry gate.
   ------------------------------------------------------------------------
   Loaded in <head>, before the page/content scripts, so the gate is up before
   anything is revealed. Three kinds of visitor:

     - COURSE: holds the portal login token (vt_portal_token). /api/me returns
               tier "course". Full access: every year + the quiz. Never sees a
               popup.
     - FREE:   registered once on this browser (name, phone, email) and holds a
               free token (vt_free_token, tier "free"). Browse only the last
               five exam years. No quiz.
     - UNREGISTERED: neither. Content stays hidden behind a one-time registration
               popup until they register (or sign in as a course student).

   Each VicThree site is a separate origin, so localStorage is not shared. A
   course student is recognised here only via the "#vt=<token>" handoff from the
   portal dashboard, or by signing in on this site. Enforcement is client-side
   convenience (the PYQ data is public); this file shows the right experience.

   Public API (window.V3):
     V3.getTier()   -> "course" | "free" | null
     V3.isCourse()  -> boolean
     V3.getStudent()-> {name,email} | null
     V3.openSignin()-> open the course sign-in popup
     V3.signOut()   -> clear the active token and reload
     V3.ready       -> Promise resolved once the stored token is validated
   -------------------------------------------------------------------------- */
(function () {
  "use strict";

  var CFG = window.VTPYQ_CONFIG || {};
  var PORTAL = (CFG.portalEndpoint || "").replace(/\/+$/, "");
  var COURSE_URL = CFG.courseUrl || "https://victhreedefence.com";
  var GFORM = CFG.googleForm || null;
  var COURSE_KEY = "vt_portal_token";
  var FREE_KEY = "vt_free_token";

  var student = null;   // {name,email}
  var tier = null;      // "course" | "free" | null
  var gateEl = null;

  function lsGet(k) { try { return localStorage.getItem(k) || ""; } catch (e) { return ""; } }
  function lsSet(k, v) { try { if (v) localStorage.setItem(k, v); else localStorage.removeItem(k); } catch (e) {} }
  function courseToken() { return lsGet(COURSE_KEY); }
  function freeToken() { return lsGet(FREE_KEY); }
  function getToken() { return courseToken() || freeToken(); }
  function authHeaders(extra) { var h = extra || {}; var t = getToken(); if (t) h["Authorization"] = "Bearer " + t; return h; }

  function esc(s) {
    return String(s == null ? "" : s).replace(/[&<>"']/g, function (c) {
      return { "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[c];
    });
  }
  function el(tag, cls, html) { var n = document.createElement(tag); if (cls) n.className = cls; if (html != null) n.innerHTML = html; return n; }
  function firstName(name) { var f = (name || "").trim().split(/\s+/)[0] || ""; return f ? f.charAt(0).toUpperCase() + f.slice(1) : ""; }

  // assets/ banner resolves relative to this script's folder.
  var BASE = (function () {
    var s = document.currentScript;
    if (!s) { var all = document.getElementsByTagName("script"); for (var i = all.length - 1; i >= 0; i--) { if (/auth\.js/.test(all[i].src)) { s = all[i]; break; } } }
    var src = (s && s.src) ? s.src : "";
    return src.replace(/js\/auth\.js(\?.*)?$/, "");
  })();

  /* ---- 1) token handoff from the portal dashboard: #vt=<token> ---- */
  (function grabHash() {
    try {
      var m = (location.hash || "").match(/[#&]vt=([^&]+)/);
      if (m) {
        lsSet(COURSE_KEY, decodeURIComponent(m[1]));
        var clean = location.hash.replace(/([#&])vt=[^&]+/, "$1").replace(/^#&/, "#").replace(/^#$/, "");
        history.replaceState(null, "", location.pathname + location.search + clean);
      }
    } catch (e) {}
  })();

  /* ---- 2) hide the page until access is resolved ---- */
  var css = [
    "html.vt-gating{overflow:hidden}",
    "html.vt-gating body>*:not(#vt-gate){visibility:hidden !important}",
    "#vt-gate{position:fixed;inset:0;z-index:1000;display:flex;align-items:flex-start;justify-content:center;",
      "overflow-y:auto;-webkit-overflow-scrolling:touch;padding:20px;",
      "background:rgba(11,31,58,.72);backdrop-filter:blur(4px);-webkit-backdrop-filter:blur(4px)}",
    "#vt-gate .vtg-mini{margin:auto;color:#fff;font-family:'Segoe UI',system-ui,-apple-system,Roboto,Arial,sans-serif;text-align:center}",
    "#vt-gate .vtg-spin{width:26px;height:26px;border:3px solid rgba(255,255,255,.35);border-top-color:#fff;border-radius:50%;animation:vtgspin .8s linear infinite;margin:0 auto 12px}",
    "#vt-gate .vtg-retry{margin-top:12px;background:#C9A24B;color:#0B1F3A;border:none;border-radius:10px;padding:10px 20px;font:inherit;font-weight:700;cursor:pointer}",
    "@keyframes vtgspin{to{transform:rotate(360deg)}}"
  ].join("");
  var st = document.createElement("style"); st.textContent = css;
  (document.head || document.documentElement).appendChild(st);
  document.documentElement.classList.add("vt-gating");

  function showChecking() {
    if (gateEl) return;
    gateEl = el("div"); gateEl.id = "vt-gate";
    gateEl.innerHTML = '<div class="vtg-mini"><div class="vtg-spin"></div>Checking access...</div>';
    (document.body || document.documentElement).appendChild(gateEl);
  }

  function showRetry() {
    removeGate();
    gateEl = el("div"); gateEl.id = "vt-gate";
    gateEl.innerHTML = '<div class="vtg-mini">Could not check your access right now.<br>' +
      '<button type="button" class="vtg-retry" id="vt-retry">Retry</button></div>';
    (document.body || document.documentElement).appendChild(gateEl);
    var b = gateEl.querySelector("#vt-retry");
    if (b) b.onclick = function () { boot(); };
  }
  function removeGate() {
    if (gateEl) {
      if (gateEl._unfit) gateEl._unfit();
      if (gateEl._esc) document.removeEventListener("keydown", gateEl._esc);
      if (gateEl.parentNode) gateEl.parentNode.removeChild(gateEl);
    }
    gateEl = null;
  }
  function closeGate() { removeGate(); } // dismiss without changing access

  function reveal(t) {
    tier = t;
    if (student) window.V3_STUDENT = student;
    document.documentElement.classList.remove("vt-gating");
    removeGate();
    renderStrip();
    try { document.dispatchEvent(new Event("v3:identity")); } catch (e) {}
  }

  /* ---- 3) the registration / sign-in popup (unregistered only) ---- */
  function openGate(initial, dismissible) {
    if (document.getElementById("vt-gate") && document.querySelector("#vt-gate .lead-card")) {
      showStep(initial || "choice"); return;
    }
    removeGate();
    gateEl = el("div"); gateEl.id = "vt-gate";
    gateEl._dismissible = !!dismissible;
    gateEl.innerHTML =
      '<div class="lead-card">' +
        '<div class="lead-banner"><img src="' + BASE + 'assets/banner.jpg" alt="VicThree Defence, by Anmol Sharma"></div>' +
        '<div class="lead-body">' +

          '<div class="v3-step" data-step="choice">' +
            '<h2 class="lead-title">Welcome to the VicThree Defence PYQ Library</h2>' +
            '<p class="v3-sub-line">Are you currently a VicThree Defence course student?</p>' +
            '<div class="v3-choice">' +
              '<button type="button" class="lead-btn" data-go="signin">Yes, sign in</button>' +
              '<button type="button" class="lead-btn v3-ghost" data-go="free">No, I\'m new</button>' +
            '</div>' +
          '</div>' +

          '<div class="v3-step" data-step="signin" style="display:none">' +
            '<h2 class="lead-title">Course student sign in</h2>' +
            '<div class="v3-sub" data-sub="email">' +
              '<label class="lead-field"><span>Your course email</span><input type="email" name="s_email" autocomplete="email"></label>' +
              '<p class="lead-error" data-err="s_email"></p>' +
              '<button type="button" class="lead-btn" data-act="send-code">Send me a code</button>' +
            '</div>' +
            '<div class="v3-sub" data-sub="code" style="display:none">' +
              '<label class="lead-field"><span>6-digit code</span><input type="text" name="s_code" inputmode="numeric" autocomplete="one-time-code" maxlength="6"></label>' +
              '<p class="lead-error" data-err="s_code"></p>' +
              '<button type="button" class="lead-btn" data-act="verify">Sign in</button>' +
            '</div>' +
            '<p class="lead-note" data-note="noaccount" style="display:none">We couldn\'t find a course account for that email. ' +
              '<a href="' + esc(COURSE_URL) + '">Not enrolled yet? See the course &rarr;</a></p>' +
            '<p class="lead-note"><button type="button" class="link-btn" data-go="choice">&larr; Back</button></p>' +
          '</div>' +

          '<div class="v3-step" data-step="free" style="display:none">' +
            '<h2 class="lead-title">Start free</h2>' +
            '<p class="v3-sub-line">Enter your details once to browse the PYQ library free.</p>' +
            '<form class="lead-form" data-form="free" novalidate>' +
              '<label class="lead-field"><span>Name</span><input type="text" name="f_name" autocomplete="name" required></label>' +
              '<label class="lead-field"><span>Phone</span><input type="tel" name="f_phone" autocomplete="tel" inputmode="numeric" required></label>' +
              '<label class="lead-field"><span>Email</span><input type="email" name="f_email" autocomplete="email" required></label>' +
              '<p class="lead-error" data-err="free"></p>' +
              '<button type="submit" class="lead-btn">Start browsing</button>' +
            '</form>' +
            '<p class="lead-note"><button type="button" class="link-btn" data-go="choice">&larr; Back</button></p>' +
          '</div>' +

        '</div>' +
      '</div>';
    (document.body || document.documentElement).appendChild(gateEl);

    var unfit = fitToViewport(gateEl);
    gateEl._unfit = unfit;
    showStep(initial || "choice");

    gateEl.addEventListener("click", function (e) {
      if (gateEl._dismissible && e.target === gateEl) { closeGate(); return; } // backdrop click
      var go = e.target.getAttribute && e.target.getAttribute("data-go");
      if (go) {
        // On a dismissible popup (opened from the strip by a signed-in free user)
        // there is no choice screen to go back to, so Back closes it.
        if (gateEl._dismissible && go === "choice") { closeGate(); return; }
        showStep(go);
        if (go === "signin") focusField('[name="s_email"]');
        else if (go === "free") focusFreeField();
        return;
      }
      var act = e.target.getAttribute && e.target.getAttribute("data-act");
      if (act === "send-code") { onSendCode(e.target); return; }
      if (act === "verify") { onVerify(e.target); return; }
    });
    if (dismissible) {
      gateEl._esc = function (e) { if (e.key === "Escape") closeGate(); };
      document.addEventListener("keydown", gateEl._esc);
    }
    gateEl.querySelector('[data-form="free"]').addEventListener("submit", function (ev) { ev.preventDefault(); onFreeSubmit(); });

    // keyboard-safe: only auto-focus a field on desktop, and only when the popup
    // opens straight onto a form step (not the choice screen). Ease a tapped
    // field into view above the keyboard.
    var finePointer = window.matchMedia && window.matchMedia("(pointer: fine)").matches;
    var step = initial || "choice";
    if (finePointer && step === "signin") focusField('[name="s_email"]');
    else if (finePointer && step === "free") focusFreeField();
    gateEl.addEventListener("focusin", function (e) {
      setTimeout(function () { try { e.target.scrollIntoView({ block: "center", behavior: "smooth" }); } catch (x) {} }, 260);
    });
  }

  function showStep(name) {
    if (!gateEl) return;
    gateEl.querySelectorAll(".v3-step").forEach(function (s) {
      s.style.display = (s.getAttribute("data-step") === name) ? "" : "none";
    });
  }
  function focusField(sel) { setTimeout(function () { try { var n = gateEl.querySelector(sel); if (n) n.focus(); } catch (x) {} }, 60); }
  function focusFreeField() { focusField('[name="f_name"]'); }

  function fitToViewport(overlay) {
    var vv = window.visualViewport;
    if (!vv) return function () {};
    function apply() { overlay.style.height = vv.height + "px"; overlay.style.top = vv.offsetTop + "px"; overlay.style.bottom = "auto"; }
    apply(); vv.addEventListener("resize", apply); vv.addEventListener("scroll", apply);
    return function () { vv.removeEventListener("resize", apply); vv.removeEventListener("scroll", apply); overlay.style.height = ""; overlay.style.top = ""; overlay.style.bottom = ""; };
  }

  /* ---- 4) network calls ---- */
  function checkMe() {
    var t = getToken(); if (!t || !PORTAL) return Promise.resolve({ ok: false });
    return fetch(PORTAL + "/api/me", { headers: authHeaders() })
      .then(function (r) {
        if (r.status !== 200) return { ok: false, status: r.status };
        return r.json().then(function (d) { return { ok: true, tier: d.tier, name: d.name, email: d.email }; });
      })
      .catch(function () { return { ok: false, status: 0 }; });
  }

  function captureToSheet(data) {
    if (!GFORM || !GFORM.action || !GFORM.fields) return;
    try {
      var b = new URLSearchParams();
      if (GFORM.fields.name) b.set(GFORM.fields.name, data.name);
      if (GFORM.fields.phone) b.set(GFORM.fields.phone, data.phone);
      if (GFORM.fields.email) b.set(GFORM.fields.email, data.email);
      fetch(GFORM.action, { method: "POST", mode: "no-cors", body: b }).catch(function () {});
    } catch (e) {}
  }

  function onFreeSubmit() {
    var name = (gateEl.querySelector('[name="f_name"]').value || "").trim();
    var phone = (gateEl.querySelector('[name="f_phone"]').value || "").trim();
    var email = (gateEl.querySelector('[name="f_email"]').value || "").trim();
    var err = gateEl.querySelector('[data-err="free"]');
    var digits = phone.replace(/\D/g, "");
    if (name.length < 2) { err.textContent = "Please enter your name."; return; }
    if (digits.length !== 10) { err.textContent = "Please enter your 10-digit mobile number."; return; }
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { err.textContent = "Please enter a valid email."; return; }
    err.textContent = "";
    var btn = gateEl.querySelector('[data-form="free"] .lead-btn');
    btn.disabled = true; btn.textContent = "Just a moment...";
    var data = { name: name, phone: phone, email: email };
    captureToSheet(data); // keep the Google Sheet lead record

    if (!PORTAL) { err.textContent = "Something went wrong, please try again."; btn.disabled = false; btn.textContent = "Start browsing"; return; }
    fetch(PORTAL + "/api/ssb/free-register", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(data) })
      .then(function (r) { return r.json().then(function (j) { return { status: r.status, body: j }; }); })
      .then(function (res) {
        if (res.status === 200 && res.body && res.body.token) {
          lsSet(FREE_KEY, res.body.token);
          student = { name: res.body.name || name, email: email };
          if (gateEl && gateEl._unfit) gateEl._unfit();
          reveal("free");
          return;
        }
        if (res.body && res.body.error === "bad_email") { err.textContent = "Please enter a valid email."; }
        else { err.textContent = "Something went wrong, please try again."; }
        btn.disabled = false; btn.textContent = "Start browsing";
      })
      .catch(function () { err.textContent = "Something went wrong, please try again."; btn.disabled = false; btn.textContent = "Start browsing"; });
  }

  function onSendCode(btn) {
    var email = (gateEl.querySelector('[name="s_email"]').value || "").trim();
    var err = gateEl.querySelector('[data-err="s_email"]');
    if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) { err.textContent = "Please enter a valid email."; return; }
    err.textContent = ""; btn.disabled = true; btn.textContent = "Sending...";
    var na = gateEl.querySelector('[data-note="noaccount"]'); if (na) na.style.display = "none";
    fetch(PORTAL + "/api/request-code", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email: email }) })
      .then(function () {
        gateEl.querySelector('[data-sub="email"]').style.display = "none";
        gateEl.querySelector('[data-sub="code"]').style.display = "";
        focusField('[name="s_code"]');
      })
      .catch(function () { err.textContent = "Something went wrong, please try again."; btn.disabled = false; btn.textContent = "Send me a code"; });
  }

  function onVerify(btn) {
    var email = (gateEl.querySelector('[name="s_email"]').value || "").trim();
    var code = (gateEl.querySelector('[name="s_code"]').value || "").trim();
    var err = gateEl.querySelector('[data-err="s_code"]');
    if (!/^\d{6}$/.test(code)) { err.textContent = "Enter the 6-digit code."; return; }
    err.textContent = ""; btn.disabled = true; btn.textContent = "Signing in...";
    fetch(PORTAL + "/api/verify", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ email: email, code: code }) })
      .then(function (r) { return r.ok ? r.json() : null; })
      .then(function (d) {
        if (d && d.token) {
          lsSet(COURSE_KEY, d.token);
          return checkMe().then(function (me) {
            if (me.ok && me.tier === "course") {
              // the page already rendered for the previous tier; reload so every
              // view (hub quiz card, all years, quiz) re-renders as course.
              location.reload();
            } else {
              // token issued but not a course account -> not enrolled.
              lsSet(COURSE_KEY, ""); showNoAccount(); btn.disabled = false; btn.textContent = "Sign in";
            }
          });
        }
        // verify failed: per spec, treat as "no course account for that email".
        err.textContent = ""; showNoAccount(); btn.disabled = false; btn.textContent = "Sign in";
      })
      .catch(function () { err.textContent = "Something went wrong, please try again."; btn.disabled = false; btn.textContent = "Sign in"; });
  }

  function showNoAccount() {
    var n = gateEl && gateEl.querySelector('[data-note="noaccount"]');
    if (n) n.style.display = "";
  }

  /* ---- 5) the persistent strip ---- */
  function renderStrip() {
    var old = document.querySelector(".v3-strip"); if (old) old.remove();
    var strip = el("div", "v3-strip");
    if (tier === "course") {
      strip.className = "v3-strip in";
      strip.innerHTML = '<span class="v3-msg">Signed in as ' + esc(student && (student.name || student.email) || "cadet") +
        ' &middot; Course access: all years and the quiz are unlocked. ' +
        '<button type="button" class="v3-link" data-v3out>Sign out</button></span>';
      strip.addEventListener("click", function (e) { if (e.target && e.target.hasAttribute("data-v3out")) signOut(); });
    } else if (tier === "free") {
      strip.className = "v3-strip free";
      strip.innerHTML = '<span class="v3-msg">Free access: last 5 years of PYQs. ' +
        'The full library and the practice quiz open up in the course. ' +
        '<a class="v3-link" href="' + esc(COURSE_URL) + '">See the course &rarr;</a>' +
        ' &middot; <button type="button" class="v3-link" data-v3signin>Course student? Sign in</button></span>';
      strip.addEventListener("click", function (e) { if (e.target && e.target.hasAttribute("data-v3signin")) openSignin(); });
    } else {
      return; // unregistered: no strip (the gate is up)
    }
    var header = document.querySelector("header.header");
    if (header && header.parentNode) header.parentNode.insertBefore(strip, header.nextSibling);
    else document.body.insertBefore(strip, document.body.firstChild);
  }

  function openSignin() {
    // open the sign-in popup over the page (dismissible), without hard-gating
    removeGate();
    openGate("signin", true);
  }

  function signOut() {
    if (tier === "course") lsSet(COURSE_KEY, "");
    else lsSet(FREE_KEY, "");
    location.reload();
  }

  /* ---- 6) boot ---- */
  var resolveReady;
  var ready = new Promise(function (res) { resolveReady = res; });

  function boot() {
    showChecking();
    checkMe().then(function (me) {
      if (me.ok && me.tier === "course") {
        student = { name: me.name, email: me.email }; reveal("course"); resolveReady(tier); return;
      }
      if (me.ok && me.tier === "free") {
        student = { name: me.name, email: me.email }; reveal("free"); resolveReady(tier); return;
      }
      // network blip while a token is present -> do not dump a student into the
      // register form; let them retry (content stays hidden, ready stays pending).
      if (me.status === 0 && getToken()) { showRetry(); return; }
      // token present but invalid (401) -> drop it.
      if (me.status === 401) { lsSet(COURSE_KEY, ""); lsSet(FREE_KEY, ""); }
      // unregistered: resolve ready as non-course so content renders (hidden)
      // behind the gate, then show the two-step entry popup (choice first).
      resolveReady(null);
      openGate("choice");
    });
  }

  function start() { if (document.body) boot(); else document.addEventListener("DOMContentLoaded", boot); }
  start();

  window.V3 = {
    getTier: function () { return tier; },
    isCourse: function () { return tier === "course"; },
    getStudent: function () { return student; },
    openSignin: openSignin,
    signOut: signOut,
    courseUrl: COURSE_URL,
    ready: ready
  };
})();
