/* Home hub: subject cards + global (All PYQs / Random-50) cards. */
function $(id){ return document.getElementById(id); }

const SUBJECT_ICON = {
  'Geography': '🌍', 'History': '🏛️', 'Polity': '⚖️', 'Economics': '📈',
  'General Science': '🔬', 'English': '✍️', 'Current Affairs': '📰',
  'Elementary Mathematics': '➗'
};

function subjectCard(s) {
  const icon = SUBJECT_ICON[s.name] || '📘';
  const topicWord = s.topics.length === 1 ? 'topic' : 'topics';
  return `<a class="hub-card" href="browse.html?subject=${encodeURIComponent(s.name)}">
    <div class="hub-ico">${icon}</div>
    <div class="hub-body">
      <div class="hub-title">${esc(s.name)}</div>
      <div class="hub-sub"><b>${s.count}</b> questions · ${s.topics.length} ${topicWord} · ${s.yearMin}–${s.yearMax}</div>
    </div>
    <div class="hub-go">›</div>
  </a>`;
}

function globalCards(t) {
  return `
  <a class="hub-card wide" href="browse.html">
    <div class="hub-ico">📚</div>
    <div class="hub-body">
      <div class="hub-title">All PYQs</div>
      <div class="hub-sub">Browse all <b>${t.questions}</b> questions across every subject, topic and year.</div>
    </div>
    <div class="hub-go">›</div>
  </a>
  <a class="hub-card wide accent" href="quiz.html">
    <div class="hub-ico">🎲</div>
    <div class="hub-body">
      <div class="hub-title">Random 50 Quiz — all subjects</div>
      <div class="hub-sub">50 random questions from the whole pool. Untimed · graded instantly with explanations.</div>
    </div>
    <div class="hub-go">›</div>
  </a>`;
}

async function init() {
  initBanner();
  try {
    await loadAll();
  } catch (err) {
    $('subject-cards').innerHTML = `<div class="empty">Failed to load data.<br>${esc(err.message)}</div>`;
    return;
  }
  renderHeaderStats('stats');
  $('subject-cards').innerHTML = VT.manifest.subjects.map(subjectCard).join('');
  $('global-cards').innerHTML = globalCards(VT.manifest.totals);
}
document.addEventListener('DOMContentLoaded', init);
