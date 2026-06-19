/* Random 50-question quiz from the entire pool. Untimed. Browser-graded. */
const QUIZ_SIZE = 50;
let pool = [];        // gradeable questions (have a-d answer + 4 options)
let current = [];     // the 50 selected
let answers = {};     // id -> chosen letter
let submitted = false;

function $(id){ return document.getElementById(id); }

function gradeablePool() {
  return VT.questions.filter(q =>
    q.answer && LETTERS.includes(q.answer) &&
    (q.options || []).filter(o => o !== '').length === 4
  );
}

function intro() {
  const max = pool.length;
  const n = Math.min(QUIZ_SIZE, max);
  $('quiz').innerHTML = `
    <div class="quiz-intro">
      <h2>Random ${n}-Question Quiz</h2>
      <p>Pulled at random from all <b>${max}</b> answerable questions across every subject, topic and year.
         Untimed — answer at your own pace, then submit to see your score with explanations.</p>
      <button class="btn block" id="start">Start quiz</button>
    </div>`;
  $('start').addEventListener('click', startQuiz);
}

function startQuiz() {
  current = shuffle(pool).slice(0, Math.min(QUIZ_SIZE, pool.length));
  answers = {};
  submitted = false;
  renderQuiz();
  window.scrollTo({ top: 0, behavior: 'auto' });
}

function quizCard(item, n) {
  const subsHtml = (item.subs && item.subs.length)
    ? `<ul class="subs">${item.subs.map(s => `<li>${esc(s)}</li>`).join('')}</ul>` : '';
  const opts = item.options.map((o, i) => {
    const L = LETTERS[i];
    return `<label class="opt quiz-opt" data-letter="${L}">
      <input type="radio" name="q_${esc(item.id)}" value="${L}">
      <span class="ol">${L})</span><span>${esc(o)}</span>
    </label>`;
  }).join('');
  return `<article class="qcard" data-id="${esc(item.id)}">
    <div class="qtop">
      <span class="tag">Q${n}</span>
      <span class="qmeta"><span class="tag topic">${esc(item.topic)}</span></span>
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
      <span class="prog" id="prog">0 / ${current.length} answered</span>
      <button class="btn" id="submit">Submit quiz</button>
    </div>
    <div id="qlist">${current.map((q, i) => quizCard(q, i + 1)).join('')}</div>
    <button class="btn block" id="submit2" style="margin-top:8px">Submit quiz</button>`;

  wrap.querySelectorAll('input[type=radio]').forEach(r => {
    r.addEventListener('change', e => {
      const id = e.target.name.slice(2);
      answers[id] = e.target.value;
      updateProgress();
    });
  });
  $('submit').addEventListener('click', submitQuiz);
  $('submit2').addEventListener('click', submitQuiz);
  updateProgress();
}

function updateProgress() {
  if (submitted) return;
  $('prog').textContent = `${Object.keys(answers).length} / ${current.length} answered`;
}

function submitQuiz() {
  if (submitted) return;
  const unanswered = current.length - Object.keys(answers).length;
  if (unanswered > 0 &&
      !confirm(`${unanswered} question(s) are unanswered and will be marked wrong. Submit anyway?`)) {
    return;
  }
  submitted = true;
  let correct = 0;

  current.forEach(item => {
    const card = document.querySelector(`.qcard[data-id="${cssEsc(item.id)}"]`);
    const chosen = answers[item.id];
    const right = item.answer;
    if (chosen === right) correct++;

    card.querySelectorAll('input[type=radio]').forEach(r => r.disabled = true);
    const correctEl = card.querySelector(`.opt[data-letter="${right}"]`);
    if (correctEl) correctEl.classList.add('correct');
    if (chosen && chosen !== right) {
      const wrongEl = card.querySelector(`.opt[data-letter="${chosen}"]`);
      if (wrongEl) wrongEl.classList.add('chosen-wrong');
    }
    const reveal = card.querySelector('.reveal');
    const idx = LETTERS.indexOf(right);
    let html = `<div class="ans">Correct: ${right}) ${esc(item.options[idx] || '')}</div>`;
    if (!chosen) html += `<div class="note">You did not answer this question.</div>`;
    if (item.explanation) html += `<div class="expl">${esc(item.explanation)}</div>`;
    html += `<div class="expl" style="margin-top:6px;color:#6b7585">${esc(item.ref)}</div>`;
    reveal.innerHTML = html;
    reveal.hidden = false;
  });

  const pct = Math.round((correct / current.length) * 100);
  const bar = `
    <div class="scorecard">
      <div class="big">${correct} / ${current.length}</div>
      <div class="pct">${pct}% correct</div>
      <div class="meta">Scroll down to review every question with the correct answer and explanation.</div>
      <div style="margin-top:14px"><button class="btn" id="again">Take a new 50-question quiz</button></div>
    </div>`;
  const qlist = $('qlist');
  qlist.insertAdjacentHTML('beforebegin', bar);
  $('again').addEventListener('click', startQuiz);

  // freeze the sticky bar into a result label
  $('prog').textContent = `Score: ${correct} / ${current.length}`;
  $('submit').textContent = 'New quiz';
  $('submit').onclick = startQuiz;
  const s2 = $('submit2'); if (s2) s2.remove();
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

/* CSS.escape fallback for older browsers */
function cssEsc(s) {
  return (window.CSS && CSS.escape) ? CSS.escape(s) : s.replace(/[^a-zA-Z0-9_-]/g, '\\$&');
}

async function init() {
  initBanner();
  try {
    await loadAll();
  } catch (err) {
    $('quiz').innerHTML = `<div class="empty">Failed to load data.<br>${esc(err.message)}</div>`;
    return;
  }
  renderHeaderStats('stats');
  pool = gradeablePool();
  if (!pool.length) {
    $('quiz').innerHTML = `<div class="empty">No answerable questions available yet.</div>`;
    return;
  }
  intro();
}
document.addEventListener('DOMContentLoaded', init);
