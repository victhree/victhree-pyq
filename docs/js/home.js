/* Home hub: All PYQs (top) · subject tiles (icon + name) · Random 50 (bottom). */
function $(id){ return document.getElementById(id); }

const SUBJECT_ICON = {
  'Art & Culture': '🎨', 'Defence': '🛡️', 'International Relations': '🌐', 'Miscellaneous': '🧩', 'Geography': '🌍', 'History': '🏛️', 'Polity': '⚖️', 'Economy': '📈', 'Economics': '📈',
  'Science': '⚛️', 'General Science': '🔬', 'English': '✍️', 'Current Affairs': '📰',
  'Elementary Mathematics': '➗'
};

function subjectTile(s) {
  const icon = SUBJECT_ICON[s.name] || '📘';
  return `<a class="subj-tile" href="browse.html?subject=${encodeURIComponent(s.name)}">
    <span class="subj-ico">${icon}</span>
    <span class="subj-name">${esc(s.name)}</span>
  </a>`;
}

function wideCard(href, icon, title, accent) {
  return `<a class="hub-card wide${accent ? ' accent' : ''}" href="${href}">
    <div class="hub-ico">${icon}</div>
    <div class="hub-body"><div class="hub-title">${title}</div></div>
    <div class="hub-go">›</div>
  </a>`;
}

async function init() {
  initBanner();
  try {
    await loadManifest();
  } catch (err) {
    $('hub').innerHTML = `<div class="empty">Failed to load data.<br>${esc(err.message)}</div>`;
    return;
  }
  renderHeaderStats('stats');
  $('hub').innerHTML =
    wideCard('browse.html', '📚', 'All PYQs', false) +
    `<div class="subj-grid">${VT.manifest.subjects.map(subjectTile).join('')}</div>` +
    wideCard('quiz.html', '🎲', 'Random 50 Quiz', true);
}
document.addEventListener('DOMContentLoaded', init);
