import http from 'k6/http';
import { check } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const voteSuccessRate = new Rate('vote_success_rate');
const totalVotesCast = new Counter('total_votes_cast');
const voteLatencyTrend = new Trend('vote_latency_ms');

export const options = {
  scenarios: {
    constant_request_rate: {
      executor: 'constant-vus',
      vus: parseInt(__ENV.VUS || '250', 10),
      duration: __ENV.DURATION || '60s',
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<50', 'p(99)<100'],
    vote_success_rate: ['rate>0.999'],
    http_req_failed: ['rate<0.001'],
  },
};

const TEAMS = [
  'Team Alpha',
  'Team Beta',
  'Team Gamma',
  'Team Delta',
];

const TARGET_URL = __ENV.VOTE_URL || 'http://localhost:3000/vote';

export default function () {
  const team = TEAMS[Math.floor(Math.random() * TEAMS.length)];
  const votes = Math.floor(Math.random() * 3) + 1;

  const payload = JSON.stringify({
    team_id: team,
    votes: votes,
    timestamp: Date.now(),
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    },
    timeout: '5s',
  };

  const startTime = Date.now();
  const res = http.post(TARGET_URL, payload, params);
  const latency = Date.now() - startTime;

  voteLatencyTrend.add(latency);

  const success = check(res, {
    'status is 200 or 202': (r) => r.status === 200 || r.status === 202,
    'latency is acceptable': () => latency < 500,
  });

  voteSuccessRate.add(success);
  if (success) {
    totalVotesCast.add(votes);
  }
}
