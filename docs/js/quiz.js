/* Random 50-question quiz. Untimed. Instant per-question feedback + running score. */
const QUIZ_SIZE = 50;
let pool = [];
let current = [];
let byId = {};
let answeredCount = 0;
let correctCount = 0;
let quizSubject = null;

function $(id){ return document.getElementById(id); }

function gradeablePool() {
  return VT.questions.filter(q =>
    (!quizSubject || q.subject === quizSubject) &&
    !q.defective &&
    q.answer && LETTERS.includes(q.answer) &&
    (q.options || []).filter(o => o !== '').length === 4
  );
}

function intro() {
  const max = pool.length;
  const n = Math.min(QUIZ_SIZE, max);
  const backHref = quizSubject ? 'browse.html?subject=' + encodeURIComponent(quizSubject) : 'index.html';
  const scopeTitle = quizSubject ? `${esc(quizSubject)} — Random ${n}-Question Quiz` : `Random ${n}-Question Quiz`;
  const scopeText = quizSubject
    ? `Pulled at random from <b>${max}</b> answerable ${esc(quizSubject)} questions.`
    : `Pulled at random from all <b>${max}</b> answerable questions across every subject, topic and year.`;
  $('quiz').innerHTML = `
    <div class="quiz-intro">
      <a class="back" href="${backHref}">← Back</a>
      <h2>${scopeTitle}</h2>
      <p>${scopeText} Untimed — tap an option to check it instantly: <b>green</b> if right, <b>red</b> if wrong, with the explanation shown right away. Your running score is at the top.</p>
      <button class="btn block" id="start">Start quiz</button>
    </div>`;
  $('start').addEventListener('click', startQuiz);
}

function startQuiz() {
  current = shuffle(pool).slice(0, Math.min(QUIZ_SIZE, pool.length));
  byId = {}; current.forEach(q => byId[q.id] = q);
  answeredCount = 0; correctCount = 0;
  renderQuiz();
  window.scrollTo({ top: 0, behavior: 'auto' });
}

function quizCard(item, n) {
  const subsHtml = (item.subs && item.subs.length)
    ? `<ul class="subs">${item.subs.map(s => `<li>${esc(s)}</li>`).join('')}</ul>` : '';
  const opts = item.options.map((o, i) =>
    `<div class="opt clickable" data-letter="${LETTERS[i]}"><span class="ol">${LETTERS[i]})</span><span>${esc(o)}</span></div>`
  ).join('');
  return `<article class="qcard" data-id="${esc(item.id)}">
    <div class="qtop">
      <span class="tag">Q${n}</span>
      <span class="qmeta"><span class="tag topic">${esc(item.subject)} · ${esc(item.topic)}</span></span>
    </div>
    <div class="qstem">${esc(item.stem)}</div>
    ${subsHtml}
    <div class="opts">${opts}</div>
    <div class="reveal" hidden></div>
  </article>`;
}

function renderQuiz() {
  const wrap = $('quiz');
  wrap.innerHTML = `
    <div class="quizbar">
      <span class="prog" id="prog"></span>
      <button class="btn" id="again">New quiz</button>
    </div>
    <div id="qlist">${current.map((q, i) => quizCard(q, i + 1)).join('')}</div>
    <button class="btn block" id="again2" style="margin-top:8px">New ${current.length}-question quiz</button>`;
  $('qlist').addEventListener('click', onQuizClick);
  $('again').addEventListener('click', startQuiz);
  $('again2').addEventListener('click', startQuiz);
  updateBar();
}

function onQuizClick(e) {
  const opt = e.target.closest('.opt.clickable');
  if (!opt) return;
  const card = e.target.closest('.qcard');
  if (!card || card.classList.contains('answered')) return;
  gradeCard(card, byId[card.dataset.id], opt.dataset.letter);
}

function gradeCard(card, item, chosen) {
  card.classList.add('answered');
  answeredCount++;
  const right = item.answer;
  const ok = (chosen === right);
  if (ok) correctCount++;
  const correctEl = card.querySelector(`.opt[data-letter="${right}"]`);
  if (correctEl) correctEl.classList.add('correct');
  if (!ok) {
    const wrongEl = card.querySelector(`.opt[data-letter="${chosen}"]`);
    if (wrongEl) wrongEl.classList.add('chosen-wrong');
  }
  const idx = LETTERS.indexOf(right);
  const reveal = card.querySelector('.reveal');
  let html = ok
    ? `<div class="ans">✓ Correct — ${right}) ${esc(item.options[idx] || '')}</div>`
    : `<div class="ans wrong">✗ You chose ${chosen}) — correct answer is ${right}) ${esc(item.options[idx] || '')}</div>`;
  if (item.explanation) html += `<div class="expl">${esc(item.explanation)}</div>`;
  html += `<div class="expl" style="margin-top:6px;color:#6b7585">${esc(item.ref)}</div>`;
  reveal.innerHTML = html;
  reveal.hidden = false;
  updateBar();
}

function updateBar() {
  const total = current.length;
  const pct = answeredCount ? Math.round((correctCount / answeredCount) * 100) : 0;
  let txt = `${answeredCount} / ${total} answered · ${correctCount} correct`;
  if (answeredCount === total) txt = `Done! Score: ${correctCount} / ${total} (${pct}%)`;
  $('prog').textContent = txt;
}

async function init() {
  initBanner();
  try {
    await loadAll();
  } catch (err) {
    $('quiz').innerHTML = `<div class="empty">Failed to load data.<br>${esc(err.message)}</div>`;
    return;
  }
  const param = new URLSearchParams(location.search).get('subject');
  quizSubject = param && VT.manifest.subjects.some(s => s.name === param) ? param : null;
  pool = gradeablePool();
  if (!pool.length) {
    $('quiz').innerHTML = `<div class="empty">No answerable questions available yet.</div>`;
    return;
  }
  intro();
}
document.addEventListener('DOMContentLoaded', init);
