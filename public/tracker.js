'use strict';

const dashboard = document.querySelector('[data-dashboard-url]');
const refreshState = dashboard.querySelector('.refresh-state');
const historyList = dashboard.querySelector('.history-list');
const refreshInterval = 60_000;

function htmlFragment(markup) {
  const template = document.createElement('template');
  template.innerHTML = markup;
  return template.content;
}

function updateDashboard(data) {
  if (!data || ['snapshot', 'history_rows', 'map_overlay', 'map_description'].some(key => typeof data[key] !== 'string')) {
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

  dashboard.querySelector('#snapshot').replaceWith(snapshot);
  historyList.replaceChildren(rows);
  dashboard.querySelector('.history-empty').hidden = historyList.children.length > 0;
  dashboard.querySelector('.map-overlay').replaceWith(overlay);
  dashboard.querySelector('#map-svg-description').textContent = data.map_description;
}

async function refresh() {
  try {
    const response = await fetch(dashboard.dataset.dashboardUrl, {
      cache: 'no-store',
      signal: AbortSignal.timeout(12_000),
    });
    if (!response.ok) throw new Error('Dashboard unavailable');
    updateDashboard(await response.json());
    refreshState.hidden = true;
  } catch {
    refreshState.hidden = false;
  } finally {
    window.setTimeout(refresh, refreshInterval);
  }
}

window.setTimeout(refresh, refreshInterval);
