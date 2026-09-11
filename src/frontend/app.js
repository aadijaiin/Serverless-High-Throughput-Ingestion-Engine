/**
 * ResilientVote Real-Time Scoreboard Client
 */

class ScoreboardApp {
  constructor() {
    this.apiEndpointInput = document.getElementById('apiEndpoint');
    this.pollToggleBtn = document.getElementById('pollToggleBtn');
    this.refreshBtn = document.getElementById('refreshBtn');
    this.liveIndicator = document.getElementById('liveIndicator');
    this.totalVotesEl = document.getElementById('totalVotes');
    this.currentRpsEl = document.getElementById('currentRps');
    this.currentLeaderEl = document.getElementById('currentLeader');
    this.leaderVotesEl = document.getElementById('leaderVotes');
    this.p95LatencyEl = document.getElementById('p95Latency');
    this.lastUpdatedEl = document.getElementById('lastUpdated');
    this.teamCountEl = document.getElementById('teamCount');
    this.teamsContainer = document.getElementById('teamsContainer');
    this.voteStatusMsg = document.getElementById('voteStatus');

    this.isPolling = true;
    this.pollInterval = 1000;
    this.pollTimer = null;

    this.previousVotes = null;
    this.previousTimestamp = null;

    this.init();
  }

  init() {
    const urlParams = new URLSearchParams(window.location.search);
    const apiParam = urlParams.get('api');
    if (apiParam) {
      this.apiEndpointInput.value = apiParam;
    } else if (window.location.origin && window.location.origin.startsWith('http')) {
      this.apiEndpointInput.value = window.location.origin;
    }

    this.pollToggleBtn.addEventListener('click', () => this.togglePolling());
    this.refreshBtn.addEventListener('click', () => this.fetchResults());

    document.querySelectorAll('.vote-btn').forEach((btn) => {
      btn.addEventListener('click', (e) => {
        const team = e.target.getAttribute('data-team');
        this.submitTestVote(team);
      });
    });

    this.fetchResults();
    this.startPolling();
  }

  startPolling() {
    if (this.pollTimer) clearInterval(this.pollTimer);
    this.pollTimer = setInterval(() => this.fetchResults(), this.pollInterval);
    this.isPolling = true;
    this.pollToggleBtn.textContent = 'Pause Polling';
    this.liveIndicator.className = 'status-indicator live';
  }

  stopPolling() {
    if (this.pollTimer) clearInterval(this.pollTimer);
    this.pollTimer = null;
    this.isPolling = false;
    this.pollToggleBtn.textContent = 'Resume Polling';
    this.liveIndicator.className = 'status-indicator';
  }

  togglePolling() {
    if (this.isPolling) {
      this.stopPolling();
    } else {
      this.startPolling();
    }
  }

  getBaseUrl() {
    let url = this.apiEndpointInput.value.trim();
    if (!url) return '';
    return url.replace(/\/+$/, '');
  }

  async fetchResults() {
    const baseUrl = this.getBaseUrl();
    const endpoint = baseUrl ? `${baseUrl}/results` : '/results';

    const startTime = performance.now();
    try {
      const response = await fetch(endpoint, {
        headers: { 'Accept': 'application/json' },
        cache: 'no-store',
      });

      const elapsedMs = Math.round(performance.now() - startTime);
      if (this.p95LatencyEl) {
        this.p95LatencyEl.innerHTML = `${elapsedMs} <span class="unit">ms</span>`;
      }

      if (!response.ok) {
        throw new Error(`HTTP ${response.status}: ${response.statusText}`);
      }

      const data = await response.json();
      this.renderScoreboard(data);
    } catch (err) {
      this.handleFetchError(err);
    }
  }

  renderScoreboard(data) {
    const totalVotes = data.total_votes || 0;
    const now = Date.now();

    if (this.previousVotes !== null && this.previousTimestamp !== null) {
      const deltaVotes = Math.max(0, totalVotes - this.previousVotes);
      const deltaSeconds = (now - this.previousTimestamp) / 1000;
      const rps = deltaSeconds > 0 ? Math.round(deltaVotes / deltaSeconds) : 0;
      this.currentRpsEl.innerHTML = `${rps.toLocaleString()} <span class="unit">RPS</span>`;
    }

    this.previousVotes = totalVotes;
    this.previousTimestamp = now;

    this.totalVotesEl.textContent = totalVotes.toLocaleString();
    this.currentLeaderEl.textContent = data.leader || '—';
    this.teamCountEl.textContent = `${data.team_count || 0} Teams Registered`;
    this.lastUpdatedEl.textContent = `Last synced: ${new Date().toLocaleTimeString()}`;

    const teams = data.teams || [];
    if (teams.length > 0 && data.leader) {
      const leaderObj = teams.find((t) => t.team_id === data.leader);
      if (leaderObj) {
        this.leaderVotesEl.textContent = `${(leaderObj.vote_count || 0).toLocaleString()} votes (${leaderObj.percentage || 0}%)`;
      }
    } else {
      this.leaderVotesEl.textContent = '0 votes recorded';
    }

    if (teams.length === 0) {
      this.teamsContainer.innerHTML = `
        <div class="loading-state">
          <p>No votes recorded yet. Cast a test vote below to initialize standings.</p>
        </div>
      `;
      return;
    }

    let html = '';
    teams.forEach((team, index) => {
      const rank = index + 1;
      const voteCount = (team.vote_count || 0).toLocaleString();
      const pct = team.percentage || 0;

      html += `
        <div class="team-row">
          <div class="team-meta">
            <div class="team-name">
              <span class="rank-badge">#${rank}</span>
              ${this.escapeHtml(team.team_id)}
            </div>
            <div class="team-tally">
              <span class="team-votes">${voteCount}</span>
              <span class="team-percentage">(${pct}%)</span>
            </div>
          </div>
          <div class="progress-track">
            <div class="progress-fill" style="width: ${pct}%"></div>
          </div>
        </div>
      `;
    });

    this.teamsContainer.innerHTML = html;
  }

  async submitTestVote(teamId) {
    const baseUrl = this.getBaseUrl();
    const endpoint = baseUrl ? `${baseUrl}/vote` : '/vote';

    this.showVoteStatus(`Submitting vote for ${teamId}...`, 'neutral');

    try {
      const response = await fetch(endpoint, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ team_id: teamId, votes: 1 }),
      });

      if (response.ok) {
        this.showVoteStatus(`✓ Vote for ${teamId} ingested into SQS buffer!`, 'success');
        setTimeout(() => this.fetchResults(), 500);
      } else {
        throw new Error(`HTTP ${response.status}`);
      }
    } catch (err) {
      this.showVoteStatus(`✗ Failed to submit vote: ${err.message}`, 'error');
    }
  }

  showVoteStatus(msg, type) {
    if (!this.voteStatusMsg) return;
    this.voteStatusMsg.textContent = msg;
    this.voteStatusMsg.className = `vote-status-msg ${type}`;
    setTimeout(() => {
      if (this.voteStatusMsg.textContent === msg) {
        this.voteStatusMsg.textContent = '';
      }
    }, 4000);
  }

  handleFetchError(err) {
    this.liveIndicator.className = 'status-indicator';
    this.lastUpdatedEl.textContent = `Sync failed: ${new Date().toLocaleTimeString()}`;
    console.error('Scoreboard fetch error:', err);
  }

  escapeHtml(str) {
    if (!str) return '';
    return str
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#039;');
  }
}

document.addEventListener('DOMContentLoaded', () => {
  new ScoreboardApp();
});
