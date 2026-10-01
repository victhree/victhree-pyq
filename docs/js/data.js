/* Shared data layer: lazy-loads the manifest + only the subject files a page needs. */
const VT = {
  manifest: null,
  questions: [],     // flat pool of currently-loaded questions
  bySubject: {},     // subjectName -> array
  _loaded: {},       // subjectName -> true once its file is loaded
  ready: false,
};

async function loadManifest() {
  if (VT.manifest) return VT.manifest;
  const res = await fetch('data/index.json', { cache: 'no-cache' });
  if (!res.ok) throw new Error('Could not load index.json');
  VT.manifest = await res.json();
  return VT.manifest;
}

/* Load specific subject files (by name). Skips any already loaded. */
async function loadSubjects(names) {
  if (!VT.manifest) await loadManifest();
  const toLoad = [];
  names.forEach(n => {
    const s = VT.manifest.subjects.find(x => x.name === n);
    if (s && !VT._loaded[n]) toLoad.push(s);
  });
  if (toLoad.length) {
    const arrays = await Promise.all(toLoad.map(async s => {
      const r = await fetch(s.file, { cache: 'no-cache' });
      if (!r.ok) throw new Error('Could not load ' + s.file);
      return { name: s.name, arr: await r.json() };
    }));
    arrays.forEach(({ name, arr }) => {
      VT._loaded[name] = true;
      arr.forEach(q => {
        VT.questions.push(q);
        (VT.bySubject[q.subject] = VT.bySubject[q.subject] || []).push(q);
      });
    });
  }
  VT.ready = true;
  return VT;
}

/* Load everything (used by the All-PYQs browse and the all-subjects quiz). */
async function loadAll() {
  await loadManifest();
  await loadSubjects(VT.manifest.subjects.map(s => s.name));
  return VT;
}

/* chronological sort key for a paper: year*10 + session(1/2) */
function paperOrder(q) {
  return (q.year || 0) * 10 + (q.session === 'II' ? 2 : 1);
}

/* The latest exam year present, and the free-tier window (last 5 years). */
function latestYear() {
  if (VT.manifest && VT.manifest.totals && VT.manifest.totals.yearMax) return VT.manifest.totals.yearMax;
  return VT.questions.reduce((m, q) => Math.max(m, q.year || 0), 0);
}
function freeMinYear() { return latestYear() - 4; }

/* Free visitors see only the last five exam years. Trims the in-memory pool in
   place so every downstream consumer (filters, counts, quiz) respects it. This
   is UX gating only; the raw JSON is public (course content is not secret). */
function limitToFreeYears() {
  const min = freeMinYear();
  VT.questions = VT.questions.filter(q => (q.year || 0) >= min);
  VT.bySubject = {};
  VT.questions.forEach(q => { (VT.bySubject[q.subject] = VT.bySubject[q.subject] || []).push(q); });
  return min;
}

/* fill the brand header + stats from manifest (no-op if the element is absent) */
function renderHeaderStats(elId) {
  const t = VT.manifest.totals;
  const el = document.getElementById(elId);
  if (!el) return;
  const subjWord = t.subjects === 1 ? 'subject' : 'subjects';
  el.innerHTML =
    `<b>${t.questions}</b> questions · <b>${t.subjects}</b> ${subjWord} · <b>${t.yearMin}–${t.yearMax}</b>`;
}

/* set banner image with graceful fallback */
function initBanner() {
  const img = document.getElementById('banner');
  if (!img) return;
  const header = img.closest('.header');
  img.addEventListener('load', () => { img.classList.add('show'); if (header) header.classList.add('has-banner'); });
  img.addEventListener('error', () => { img.classList.remove('show'); if (header) header.classList.remove('has-banner'); });
  img.src = 'assets/banner.jpg';
}

/* escape for safe HTML insertion */
function esc(s) {
  return String(s == null ? '' : s)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

const LETTERS = ['a', 'b', 'c', 'd'];

/* Fisher–Yates shuffle (returns new array) */
function shuffle(arr) {
  const a = arr.slice();
  for (let i = a.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [a[i], a[j]] = [a[j], a[i]];
  }
  return a;
}

/* ---------- bookmarks & progress (saved on the device) ---------- */
function getBookmarks() {
  try { return new Set(JSON.parse(localStorage.getItem('vt_bookmarks') || '[]')); }
  catch (e) { return new Set(); }
}
function saveBookmarks(set) {
  try { localStorage.setItem('vt_bookmarks', JSON.stringify([...set])); } catch (e) {}
}
function toggleBookmark(id) {
  const s = getBookmarks();
  if (s.has(id)) s.delete(id); else s.add(id);
  saveBookmarks(s);
  return s.has(id);
}
function getProgress() {
  try { return JSON.parse(localStorage.getItem('vt_progress') || '{}'); }
  catch (e) { return {}; }
}
function setProgress(id, val) {
  try { const p = getProgress(); p[id] = val; localStorage.setItem('vt_progress', JSON.stringify(p)); }
  catch (e) {}
}

/* register the service worker for offline / installable use (no-op if unsupported) */
if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('sw.js').catch(() => {});
  });
}
