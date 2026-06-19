/* Shared data layer: loads the manifest + subject files, exposes helpers. */
const VT = {
  manifest: null,
  questions: [],     // flat pool of all questions across subjects
  bySubject: {},     // subjectName -> array
  ready: false,
};

async function loadAll() {
  const res = await fetch('data/index.json', { cache: 'no-cache' });
  if (!res.ok) throw new Error('Could not load index.json');
  VT.manifest = await res.json();

  const files = VT.manifest.subjects.map(s => s.file);
  const arrays = await Promise.all(files.map(async f => {
    const r = await fetch(f, { cache: 'no-cache' });
    if (!r.ok) throw new Error('Could not load ' + f);
    return r.json();
  }));

  VT.questions = [];
  VT.bySubject = {};
  arrays.forEach((arr) => {
    arr.forEach(q => VT.questions.push(q));
  });
  VT.questions.forEach(q => {
    (VT.bySubject[q.subject] = VT.bySubject[q.subject] || []).push(q);
  });
  VT.ready = true;
  return VT;
}

/* chronological sort key for a paper: year*10 + session(1/2) */
function paperOrder(q) {
  return (q.year || 0) * 10 + (q.session === 'II' ? 2 : 1);
}

/* fill the brand header + stats from manifest */
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
