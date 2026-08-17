import http from "k6/http";
import { check, sleep } from "k6";

const vus = Number(__ENV.K6_VUS || 25);
const duration = __ENV.K6_DURATION || "60s";
const apiKey = __ENV.API_KEY || "lab-secret-key";
const baseUrl = __ENV.API_BASE_URL || "https://api.localhost";

export const options = {
  insecureSkipTLSVerify: true,
  scenarios: {
    api_load: {
      executor: "constant-vus",
      vus,
      duration,
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.20"],
    http_req_duration: ["p(95)<1500"],
  },
};

const params = {
  headers: {
    "X-API-Key": apiKey,
  },
  timeout: "5s",
};

export default function () {
  // Clear cache occasionally so the test exercises both Redis and MySQL.
  if (Math.random() < 0.05) {
    http.post(`${baseUrl}/api/cache/clear`, null, params);
  }

  const response = http.get(`${baseUrl}/api/items`, params);
  check(response, {
    "API returned 200": (r) => r.status === 200,
    "response contains products": (r) => r.body && r.body.includes("products"),
  });

  // Hit a slow endpoint occasionally so the latency alert has real data.
  if (Math.random() < 0.10) {
    http.get(`${baseUrl}/api/slow?delay_ms=300`, params);
  }

  sleep(0.2);
}

