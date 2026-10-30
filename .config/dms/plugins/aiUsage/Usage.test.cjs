const assert = require("node:assert/strict");
const fs = require("node:fs");
const vm = require("node:vm");

const source = fs.readFileSync(require("node:path").join(__dirname, "Usage.js"), "utf8");
const context = {};
vm.runInNewContext(source + "\nthis.api = { normalize, chooseTop, windowDetail };", context);
const { normalize, chooseTop, windowDetail } = context.api;

const now = Date.UTC(2026, 9, 19, 12, 0, 0);

{
  const result = normalize(JSON.stringify([
    { provider: "codex", usage: { secondary: { usedPercent: 41, windowMinutes: 10080, resetsAt: "2026-10-23T12:00:00Z" }, providerCost: { currencyCode: "USD", balance: 14.46 } } },
    { provider: "claude", error: { kind: "provider", message: "credentials unavailable", code: 1 } }
  ]), "codexbar", now);
  assert.equal(result.providers[0].windows.length, 1);
  assert.equal(result.providers[0].windows[0].percent, 41);
  assert.equal(result.providers[0].windows[0].amountText, null);
  assert.match(result.warnings.join("\n"), /credentials unavailable/);
  const top = chooseTop(result.providers);
  assert.equal(top.name, "Codex");
  assert.equal(top.label, "Weekly");
  assert.match(result.providers[0].details.join("\n"), /\$14.46/);
}

{
  const result = normalize(JSON.stringify({
    generatedAt: now,
    reports: [{ provider: "opencode-go", fetchedAt: now, limits: [
      { id: "rolling-5h", window: { id: "5h", label: "5 Hour", durationMs: 18000000, resetsAt: now + 4500000 }, amount: { usedFraction: 0.2, unit: "percent" } },
      { id: "weekly", window: { id: "7d", label: "Weekly", durationMs: 604800000, resetsAt: now + 604800000 }, amount: { usedFraction: 0.3, unit: "percent" } },
      { id: "monthly", window: { id: "monthly", label: "Monthly", resetsAt: Date.UTC(2026, 9, 20, 12) }, amount: { usedFraction: 0.4, unit: "percent" }, notes: ["OMP-observed spend only"] }
    ] }]
  }), "omp", now);
  const windows = result.providers[0].windows;
  assert.equal(windows.length, 3);
  assert.equal(windows[0].percent, 20);
  assert.equal(windows[0].expectedPercent, 75);
  assert.equal(windows[1].expectedPercent, 0);
  assert.ok(windows[2].durationMs >= 30 * 86400000);
  assert.ok(windows[2].expectedPercent > 95 && windows[2].expectedPercent < 100);
  assert.match(windowDetail(windows[2], now), /OMP-observed spend only/);
}

{
  const result = normalize(JSON.stringify({ reports: [{ provider: "openai-codex", limits: [
    { id: "bad", window: { label: "Session", durationMs: 3600000, resetsAt: now + 3600000 }, amount: { usedFraction: null, usedPercent: "NaN", unit: "percent" } },
    { id: "money", window: { label: "Paid", durationMs: 3600000, resetsAt: now + 3600000 }, amount: { used: 12.5, limit: 20, unit: "USD" } },
    { id: "over", window: { label: "Overage", durationMs: 3600000, resetsAt: now + 3600000 }, amount: { usedFraction: 1.2, unit: "percent" } }
  ], resetCredits: { availableCount: 0 } }, { provider: "claude", resetCredits: {
    availableCount: 2,
    credits: [{ status: "available", expiresAt: "2026-10-21T12:00:00Z" }, { status: "available", usable: false, expiresAt: "2026-10-20T12:00:00Z" }, { status: "redeemed", expiresAt: "2026-10-19T12:00:00Z" }]
  } }] }), "omp", now);
  assert.equal(result.providers[0].windows.length, 2);
  assert.equal(result.providers[0].windows[0].amountText, "$12.5 / $20");
  assert.equal(result.providers[0].windows[1].percent, 120);
  assert.match(result.warnings.join("\n"), /unusable percentage/);
}

{
  const result = normalize(JSON.stringify({ reports: [{ provider: "opencode-go", limits: [
    { id: "monthly", window: { id: "monthly", label: "Monthly", resetsAt: Date.UTC(2026, 2, 31, 12) }, amount: { usedFraction: 0.1, unit: "percent" } }
  ] }] }), "omp", Date.UTC(2026, 2, 1, 12));
  assert.equal(result.providers[0].windows[0].durationMs, 31 * 86400000);
}
