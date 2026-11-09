'use strict';

const dashboard = document.querySelector('[data-dashboard-url]');
const refreshState = dashboard.querySelector('.refresh-state');
const announcement = dashboard.querySelector('.refresh-announcement');
const historyList = dashboard.querySelector('.history-list');
const more = dashboard.querySelector('.history-more');
const historyFeedback = dashboard.querySelector('.history-feedback');
const refreshInterval = 60_000;
let olderCursor = more.dataset.before === '' ? null : Number(more.dataset.before);
let browsingOlder = false;
let loadingOlder = false;

function htmlFragment(markup) {
  const template = document.createElement('template');
  template.innerHTML = markup;
  return template.content;
}

function validCursor(value) {
  return value === null || (Number.isSafeInteger(value) && value >= 0);
}

function syncHistoryButton() {
  more.hidden = olderCursor === null && !browsingOlder;
  more.setAttribute('aria-disabled', String(loadingOlder || olderCursor === null));
  more.textContent = loadingOlder ? 'Загружаем историю…'
    : olderCursor === null ? 'Вся история загружена' : 'Показать более ранние пролёты';
}

function mergeHistory(rows) {
  const current = new Map(Array.from(historyList.children, row => [row.dataset.observedAt, row]));
  let overlap = false;
  for (const row of rows.children) {
    const timestamp = row.dataset.observedAt;
    if (current.has(timestamp)) overlap = true;
    else current.set(timestamp, row);
  }
  historyList.replaceChildren(...Array.from(current.values()).sort((a, b) => b.dataset.observedAt - a.dataset.observedAt));
  return overlap;
}

async function fetchJson(url) {
  const response = await fetch(url, {cache: 'no-store', signal: AbortSignal.timeout(12_000)});
  if (!response.ok) throw new Error('Request unavailable');
  return response.json();
}

async function loadOlder() {
  if (loadingOlder || olderCursor === null) return;
  loadingOlder = true;
  syncHistoryButton();
  historyFeedback.textContent = '';
  const before = olderCursor;
  const url = new URL(dashboard.dataset.historyUrl, window.location.href);
  url.searchParams.set('before', before);
  url.searchParams.set('view', 'html');
  try {
    const data = await fetchJson(url);
    if (!data || typeof data.history_rows !== 'string' || !validCursor(data.next_before)) throw new Error('Invalid history');
    mergeHistory(htmlFragment(data.history_rows));
    browsingOlder = true;
    if (olderCursor === before) olderCursor = data.next_before;
    historyFeedback.textContent = 'История обновлена.';
  } catch {
    historyFeedback.textContent = 'Не удалось загрузить историю. Попробуйте ещё раз.';
  } finally {
    loadingOlder = false;
    syncHistoryButton();
  }
}

function updateDashboard(data) {
  if (!data || !validCursor(data.next_before)
    || ['snapshot', 'history_rows', 'map_overlay', 'map_description'].some(key => typeof data[key] !== 'string')) {
    throw new Error('Invalid dashboard data');
  }
  const snapshot = htmlFragment(data.snapshot).firstElementChild;
  const rows = htmlFragment(data.history_rows);
  const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg');
  svg.innerHTML = data.map_overlay;
  const overlay = svg.firstElementChild;
  if (!snapshot?.matches('#snapshot') || !overlay?.matches('.map-overlay')) {
    throw new Error('Invalid dashboard fragments');
  }

  const previousSnapshot = dashboard.querySelector('#snapshot');
  const newObservation = snapshot.dataset.observedAt && snapshot.dataset.observedAt !== previousSnapshot.dataset.observedAt;
  const observationTime = snapshot.querySelector('.snapshot-time')?.textContent;
  if (newObservation && !observationTime) throw new Error('Invalid observation time');
  previousSnapshot.replaceWith(snapshot);
  if (!browsingOlder && !loadingOlder) {
    historyList.replaceChildren(rows);
    olderCursor = data.next_before;
  } else if (!mergeHistory(rows)) {
    olderCursor = data.next_before;
  }
  syncHistoryButton();
  dashboard.querySelector('.history-empty').hidden = historyList.children.length > 0;
  dashboard.querySelector('.map-overlay').replaceWith(overlay);
  dashboard.querySelector('#map-svg-description').textContent = data.map_description;
  if (newObservation) {
    announcement.textContent = 'Получено новое наблюдение. ' + observationTime;
  }
  return newObservation;
}

async function refresh() {
  try {
    const updated = updateDashboard(await fetchJson(dashboard.dataset.dashboardUrl));
    if (!refreshState.hidden && !updated) announcement.textContent = 'Связь с сервером восстановлена.';
    refreshState.hidden = true;
  } catch {
    if (refreshState.hidden) announcement.textContent = refreshState.textContent;
    refreshState.hidden = false;
  } finally {
    window.setTimeout(refresh, refreshInterval);
  }
}

more.addEventListener('click', loadOlder);
syncHistoryButton();
window.setTimeout(refresh, refreshInterval);
