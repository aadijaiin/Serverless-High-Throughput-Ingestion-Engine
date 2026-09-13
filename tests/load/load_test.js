import http from 'k6/http';
import { check } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const voteSuccessRate = new Rate('vote_success_rate');
const totalVotesCast = new Counter('total_votes_cast');
const voteLatencyTrend = new Trend('vote_latency_ms');

// Total duration: 3s + 3s + 3s + 3s = 12s
export const options = {
  scenarios: {
    precision_burst: {
      executor: 'ramping-arrival-rate',
      startRate: 500,
      timeUnit: '1s',
      preAllocatedVUs: 1500, // Pre-allocates memory so it won't stutter during the spike
      maxVUs: 4000,
      stages: [
        { duration: '3s', target: 2000 },  // 0s-3s: Ramp to 2k RPS
        { duration: '3s', target: 10000 }, // 3s-6s: Surge to 10k RPS
        { duration: '3s', target: 10000 }, // 6s-9s: Hold steady at 10,000 RPS
        { duration: '3s', target: 0 },     // 9s-12s: Cool down to 0
      ],
    },
  },
  thresholds: {
    http_req_duration: ['p(95)<60', 'p(99)<120'],
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
    timeout: '3s',
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