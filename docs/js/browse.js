/* Browse page: subject/topic/subtopic/paper filters + search + sort + interactive answers. */
const els = {};
function $(id){ return document.getElementById(id); }

function fillSelect(sel, options, allLabel) {
  sel.innerHTML = '';
  const optAll = document.createElement('option');
  optAll.value = '__all__'; optAll.textContent = allLabel;
  sel.appendChild(optAll);
  options.forEach(o => {
    const el = document.createElement('option');
    el.value = o.value; el.textContent = o.label;
    sel.appendChild(el);
  });
}

function currentSubject() {
  const v = els.subject.value;
  return v === '__all__' ? null : v;
}

/* topic + paper dropdowns depend on the selected subject */
function refreshDependentFilters(keepTopic, keepPaper) {
  const subjName = currentSubject();
  let topics = [], papers = [];

  if (subjName) {
    const s = VT.manifest.subjects.find(x => x.name === subjName);
    topics = s.topics.map(t => ({ value: t.name, label: `${t.name} (${t.count})` }));
    papers = s.papers.map(p => ({ value: p.name, label: `${p.name} (${p.count})` }));
  } else {
    const tcount = {}, pcount = {}, pmeta = {};
    VT.questions.forEach(q => {
      tcount[q.topic] = (tcount[q.topic] || 0) + 1;
      pcount[q.paper] = (pcount[q.paper] || 0) + 1;
      pmeta[q.paper] = paperOrder(q);
    });
    topics = Object.keys(tcount).sort().map(t => ({ value: t, label: `${t} (${tcount[t]})` }));
    papers = Object.keys(pcount).sort((a, b) => pmeta[b] - pmeta[a])
      .map(p => ({ value: p, label: `${p} (${pcount[p]})` }));
  }

  fillSelect(els.topic, topics, 'All topics');
  fillSelect(els.paper, papers, 'All years / papers');
  if (keepTopic && [...els.topic.options].some(o => o.value === keepTopic)) els.topic.value = keepTopic;
  if (keepPaper && [...els.paper.options].some(o => o.value === keepPaper)) els.paper.value = keepPaper;
  refreshSubtopics();
}

/* subtopic dropdown depends on the selected subject + topic */
function refreshSubtopics(keepSub) {
  const subjName = currentSubject();
  const topic = els.topic.value;
  const counts = {};
  VT.questions.forEach(q => {
    if (subjName && q.subject !== subjName) return;
    if (topic !== '__all__' && q.topic !== topic) return;
    if (!q.subtopic) return;
    counts[q.subtopic] = (counts[q.subtopic] || 0) + 1;
  });
  const opts = Object.keys(counts).sort()
    .map(s => ({ value: s, label: `${s} (${counts[s]})` }));
  fillSelect(els.subtopic, opts, 'All subtopics');
  if (keepSub && [...els.subtopic.options].some(o => o.value === keepSub)) els.subtopic.value = keepSub;
}

function getFiltered() {
  const subjName = currentSubject();
  const topic = els.topic.value;
  const subtopic = els.subtopic.value;
  const paper = els.paper.value;
  const q = els.search.value.trim().toLowerCase();

  let list = VT.questions.filter(item => {
    if (subjName && item.subject !== subjName) return false;
    if (topic !== '__all__' && item.topic !== topic) return false;
    if (subtopic !== '__all__' && item.subtopic !== subtopic) return false;
    if (paper !== '__all__' && item.paper !== paper) return false;
    if (q) {
      const hay = (item.stem + ' ' + (item.subs || []).join(' ') + ' ' +
                   (item.options || []).join(' ') + ' ' + item.subtopic).toLowerCase();
      if (!hay.includes(q)) return false;
    }
    return true;
  });

  const sort = els.sort.value;
  list.sort((a, b) => {
    if (sort === 'topic') {
      return (a.topic + a.subtopic).localeCompare(b.topic + b.subtopic) ||
             paperOrder(b) - paperOrder(a);
    }
    const d = paperOrder(a) - paperOrder(b);
    const byYear = sort === 'year-asc' ? d : -d;
    return byYear || (a.qno - b.qno);
  });
  return list;
}

function questionCard(item) {
  const subsHtml = (item.subs && item.subs.length)
    ? `<ul class="subs">${item.subs.map(s => `<li>${esc(s)}</li>`).join('')}</ul>` : '';

  const hasAns = item.answer && LETTERS.includes(item.answer);
  const optsHtml = `<div class="opts">${
    (item.options || []).map((o, i) =>
      o === '' ? '' :
      `<div class="opt${hasAns ? ' clickable' : ''}" data-letter="${LETTERS[i]}"><span class="ol">${LETTERS[i]})</span><span>${esc(o)}</span></div>`
    ).join('')
  }</div>`;

  const topicTag = `<span class="tag topic">${esc(item.topic)}${item.subtopic ? ' · ' + esc(item.subtopic) : ''}</span>`;
  const warnTag = item.defective ? `<span class="tag warn">⚠ Verify vs original</span>` : '';
  const hint = hasAns ? `<div class="opt-hint">Tap an option to check it, or </div>` : '';

  return `<article class="qcard" data-id="${esc(item.id)}">
    <div class="qtop">
      <span class="tag">★ ${esc(item.ref)}</span>
      <span class="qmeta">${warnTag}${topicTag}</span>
    </div>
    <div class="qstem">${esc(item.stem)}</div>
    ${subsHtml}
    ${optsHtml}
    <button class="btn ghost show-btn" data-act="show">Show answer</button>
    <div class="reveal" hidden></div>
  </article>`;
}

/* Reveal the answer. If `chosen` is given, grade that option (green/right, red/wrong). */
function revealAnswer(card, item, chosen) {
  if (card.classList.contains('answered')) return;
  card.classList.add('answered');
  const reveal = card.querySelector('.reveal');
  const hasLetter = item.answer && LETTERS.includes(item.answer);
  let html = '';
  if (hasLetter) {
    const idx = LETTERS.indexOf(item.answer);
    const correctEl = card.querySelector(`.opt[data-letter="${item.answer}"]`);
    if (correctEl) correctEl.classList.add('correct');
    if (chosen && chosen !== item.answer) {
      const wrongEl = card.querySelector(`.opt[data-letter="${chosen}"]`);
      if (wrongEl) wrongEl.classList.add('chosen-wrong');
      html += `<div class="ans wrong">✗ You chose ${chosen}) — correct answer is ${item.answer}) ${esc(item.options[idx] || '')}</div>`;
    } else if (chosen) {
      html += `<div class="ans">✓ Correct — ${item.answer}) ${esc(item.options[idx] || '')}</div>`;
    } else {
      html += `<div class="ans">Correct answer: ${item.answer}) ${esc(item.options[idx] || '')}</div>`;
    }
  } else {
    html += `<div class="ans none">Answer not available for this question</div>`;
  }
  if (item.explanation) html += `<div class="expl">${esc(item.explanation)}</div>`;
  if (item.answerNote) html += `<div class="note">Source note: ${esc(item.answerNote)}</div>`;
  reveal.innerHTML = html;
  reveal.hidden = false;
  const btn = card.querySelector('[data-act="show"]');
  if (btn) { btn.textContent = 'Reset'; btn.dataset.act = 'hide'; }
}

const RENDER_CAP = 120;
let expanded = false;

function render() {
  const list = getFiltered();
  els.rcount.textContent = `${list.length} question${list.length === 1 ? '' : 's'}`;
  if (!list.length) {
    els.results.innerHTML = `<div class="empty">No questions match these filters.<br>Try “Reset filters”.</div>`;
    return;
  }
  const shown = (expanded || list.length <= RENDER_CAP) ? list : list.slice(0, RENDER_CAP);
  let html = shown.map(questionCard).join('');
  if (shown.length < list.length) {
    html += `<button class="btn block" data-act="expand" style="margin-top:6px">
      Show all ${list.length} questions</button>`;
  }
  els.results.innerHTML = html;
  const byId = {}; list.forEach(q => byId[q.id] = q);
  els.results._byId = byId;
}

function applyFilters() { expanded = false; render(); }

function onResultsClick(e) {
  // clicking an option → grade it instantly
  const opt = e.target.closest('.opt.clickable');
  const oc = e.target.closest('.qcard');
  if (opt && oc && !oc.classList.contains('answered')) {
    const item = els.results._byId[oc.dataset.id];
    revealAnswer(oc, item, opt.dataset.letter);
    return;
  }
  const btn = e.target.closest('[data-act]');
  if (!btn) return;
  if (btn.dataset.act === 'expand') { expanded = true; render(); return; }
  const card = btn.closest('.qcard');
  const item = els.results._byId[card.dataset.id];
  if (btn.dataset.act === 'show') {
    revealAnswer(card, item, null);
  } else {
    card.classList.remove('answered');
    card.querySelector('.reveal').hidden = true;
    card.querySelectorAll('.opt.correct, .opt.chosen-wrong').forEach(o => o.classList.remove('correct', 'chosen-wrong'));
    btn.textContent = 'Show answer';
    btn.dataset.act = 'show';
  }
}

function debounce(fn, ms) { let t; return () => { clearTimeout(t); t = setTimeout(fn, ms); }; }

/* header above the filters: back link, title, and the scoped Random-50 button */
function renderSubjectHead(name) {
  const el = $('subjecthead');
  if (!el) return;
  if (name) {
    const s = VT.manifest.subjects.find(x => x.name === name);
    document.title = `${name} — VicThree Defence CDS PYQ`;
    el.innerHTML =
      `<a class="back" href="index.html">← All subjects</a>
       <h2 class="sh-title">${esc(name)} <span class="sh-count">${s ? s.count : ''} Qs</span></h2>
       <div class="quiz-cta"><a class="btn quizbtn" href="quiz.html?subject=${encodeURIComponent(name)}">🎲 Random 50 Quiz — ${esc(name)}</a></div>`;
  } else {
    el.innerHTML =
      `<a class="back" href="index.html">← Home</a>
       <h2 class="sh-title">All PYQs</h2>
       <div class="quiz-cta"><a class="btn quizbtn" href="quiz.html">🎲 Random 50 Quiz — all subjects</a></div>`;
  }
}

async function init() {
  els.subject = $('f-subject'); els.topic = $('f-topic'); els.subtopic = $('f-subtopic');
  els.paper = $('f-paper');
  els.sort = $('f-sort'); els.search = $('f-search'); els.results = $('results');
  els.rcount = $('rcount');
  initBanner();
  try {
    await loadAll();
  } catch (err) {
    els.results.innerHTML = `<div class="empty">Failed to load data.<br>${esc(err.message)}</div>`;
    return;
  }

  const subs = VT.manifest.subjects.map(s => ({ value: s.name, label: `${s.name} (${s.count})` }));
  fillSelect(els.subject, subs, 'All subjects');

  const param = new URLSearchParams(location.search).get('subject');
  const locked = param && VT.manifest.subjects.some(s => s.name === param) ? param : null;
  if (locked) {
    els.subject.value = locked;
    const fld = $('field-subject'); if (fld) fld.style.display = 'none';
  }
  renderSubjectHead(locked);
  refreshDependentFilters();

  els.subject.addEventListener('change', () => { refreshDependentFilters(); applyFilters(); });
  els.topic.addEventListener('change', () => { refreshSubtopics(); applyFilters(); });
  els.subtopic.addEventListener('change', applyFilters);
  els.paper.addEventListener('change', applyFilters);
  els.sort.addEventListener('change', applyFilters);
  els.search.addEventListener('input', debounce(applyFilters, 180));
  els.results.addEventListener('click', onResultsClick);
  $('f-reset').addEventListener('click', () => {
    if (!locked) els.subject.value = '__all__';
    els.sort.value = 'year-desc'; els.search.value = '';
    refreshDependentFilters(); applyFilters();
  });

  applyFilters();
}
document.addEventListener('DOMContentLoaded', init);
