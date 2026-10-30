/* QML-compatible usage normalization. Keep this file free of Node or platform APIs. */

var HOUR_MS = 60 * 60 * 1000;
var DAY_MS = 24 * HOUR_MS;
var WEEK_MS = 7 * DAY_MS;

function isObject(value) {
    return value !== null && typeof value === "object" && !Array.isArray(value);
}

function stringValue(value) {
    return typeof value === "string" && value.trim().length > 0 ? value.trim() : null;
}

function finiteNumber(value) {
    if (typeof value === "number") {
        return isFinite(value) ? value : null;
    }
    if (typeof value === "string" && value.trim().length > 0) {
        var parsed = Number(value);
        return isFinite(parsed) ? parsed : null;
    }
    return null;
}

function positiveNumber(value) {
    var parsed = finiteNumber(value);
    return parsed !== null && parsed > 0 ? parsed : null;
}

function own(object, key) {
    return Object.prototype.hasOwnProperty.call(object, key);
}

function firstValue(object, keys) {
    if (!isObject(object)) return null;
    for (var i = 0; i < keys.length; i++) {
        if (own(object, keys[i]) && object[keys[i]] !== null && object[keys[i]] !== undefined) {
            return object[keys[i]];
        }
    }
    return null;
}

function timestamp(value) {
    if (value === null || value === undefined || value === "") return null;
    var numeric = finiteNumber(value);
    if (numeric !== null) {
        // Epoch seconds are still common in provider adapters; OMP uses milliseconds.
        return Math.abs(numeric) < 100000000000 ? numeric * 1000 : numeric;
    }
    if (typeof value === "string") {
        var parsed = Date.parse(value);
        return isNaN(parsed) ? null : parsed;
    }
    return null;
}

function clampPercent(value) {
    var numeric = finiteNumber(value);
    if (numeric === null) return null;
    return Math.max(0, Math.min(100, numeric));
}

function percentFromFraction(value) {
    var fraction = finiteNumber(value);
    return fraction === null ? null : clampPercent(fraction * 100);
}

function friendlyName(provider) {
    var value = stringValue(provider) || "Unknown";
    var lower = value.toLowerCase();
    if (lower === "openai-codex" || lower === "codex") return lower === "codex" ? "Codex" : "OpenAI Codex";
    if (lower === "opencode-go") return "OpenCode Go";
    if (lower === "claude") return "Claude";
    if (lower === "gemini") return "Gemini";
    return value;
}

function providerIdentity(source, usage, metadata) {
    var identity = firstValue(metadata, ["email", "accountEmail", "account", "accountId", "orgId"]);
    if (!identity) identity = firstValue(source, ["accountEmail", "email", "account"]);
    if (!identity && isObject(usage)) {
        var usageIdentity = usage.identity;
        if (typeof usageIdentity === "string") identity = usageIdentity;
        else if (isObject(usageIdentity)) identity = firstValue(usageIdentity, ["accountEmail", "email", "account", "providerID"]);
    }
    return stringValue(identity) || "";
}

function providerPlan(source, usage, metadata) {
    var plan = firstValue(metadata, ["planType", "plan", "tier"]);
    if (!plan) plan = firstValue(source, ["plan", "planType", "tier"]);
    if (!plan && isObject(usage)) plan = firstValue(usage, ["plan", "planType", "tier"]);
    return stringValue(plan) || "";
}

function newProvider(rawName, identity, plan, fetchedAt) {
    return {
        name: friendlyName(rawName),
        identity: identity || "",
        plan: plan || "",
        windows: [],
        details: [],
        error: "",
        fetchedAt: fetchedAt
    };
}

function addUnique(list, value) {
    if (!value) return;
    for (var i = 0; i < list.length; i++) if (list[i] === value) return;
    list.push(value);
}

function normalizeNotes(notes) {
    if (!Array.isArray(notes)) return [];
    var result = [];
    for (var i = 0; i < notes.length; i++) {
        var note = stringValue(notes[i]);
        if (note) addUnique(result, note);
    }
    return result;
}

function addNotes(provider, notes, label) {
    var normalized = normalizeNotes(notes);
    for (var i = 0; i < normalized.length; i++) {
        addUnique(provider.details, (label ? label + ": " : "") + "Note: " + normalized[i]);
    }
    return normalized;
}

function errorMessage(value) {
    if (typeof value === "string") return stringValue(value) || "";
    if (!isObject(value)) return "";
    return stringValue(firstValue(value, ["message", "error", "description", "reason"])) || "Provider request failed";
}

function actualPercent(value) {
    var numeric = finiteNumber(value);
    return numeric === null || numeric < 0 ? null : numeric;
}

function percentFromFraction(value) {
    var fraction = finiteNumber(value);
    return fraction === null || fraction < 0 ? null : fraction * 100;
}

function percentFromAmount(amount) {
    if (!isObject(amount)) return null;
    var fraction = firstValue(amount, ["usedFraction", "usageFraction", "consumedFraction"]);
    if (fraction !== null) {
        var fractionPercent = percentFromFraction(fraction);
        if (fractionPercent !== null) return fractionPercent;
    }

    var used = finiteNumber(firstValue(amount, ["used"]));
    var limit = finiteNumber(firstValue(amount, ["limit"]));
    if (used !== null && used >= 0 && limit !== null && limit > 0) return (used / limit) * 100;

    var unit = (stringValue(firstValue(amount, ["unit"])) || "").toLowerCase();
    if (unit === "percent" && used !== null) return actualPercent(used);
    var remainingFraction = finiteNumber(firstValue(amount, ["remainingFraction"]));
    if (remainingFraction !== null && remainingFraction >= 0) return actualPercent((1 - remainingFraction) * 100);

    var direct = firstValue(amount, ["usedPercent", "percent", "usagePercent"]);
    return direct === null ? null : actualPercent(direct);
}

function formatNumber(number) {
    var value = finiteNumber(number);
    if (value === null) return null;
    if (Math.round(value) === value) return String(value);
    return String(Math.round(value * 100) / 100);
}


function amountTextFor(amount) {
    if (!isObject(amount)) return null;
    var explicit = firstValue(amount, ["amountText"]);
    if (typeof explicit === "string" && explicit.trim()) return explicit.trim();

    var unit = stringValue(firstValue(amount, ["unit"]));
    if (!unit || unit.toLowerCase() !== "usd") return null;
    var used = finiteNumber(firstValue(amount, ["used"]));
    var remaining = finiteNumber(firstValue(amount, ["remaining"]));
    var limit = finiteNumber(firstValue(amount, ["limit"]));
    var usedText = formatNumber(used);
    var remainingText = formatNumber(remaining);
    var limitText = formatNumber(limit);
    if (usedText !== null && limitText !== null) return "$" + usedText + " / $" + limitText;
    if (remainingText !== null) return "$" + remainingText + " remaining";
    if (usedText !== null) return "$" + usedText + " used";
    if (limitText !== null) return "$" + limitText + " limit";
    return null;
}

function addOmpMonetaryDetail(provider, amount, label) {
    if (!isObject(amount) || String(amount.unit || "").toLowerCase() !== "usd") return;
    var text = amountTextFor(amount);
    if (text) addUnique(provider.details, (label || "Usage") + " amount: " + text);
}

function durationFor(windowObject, limit) {
    var duration = positiveNumber(firstValue(windowObject, ["durationMs", "windowDurationMs"]));
    if (!duration) duration = positiveNumber(firstValue(limit, ["durationMs", "windowDurationMs"]));
    if (!duration) {
        var minutes = positiveNumber(firstValue(windowObject, ["windowMinutes", "minutes"]));
        if (!minutes) minutes = positiveNumber(firstValue(limit, ["windowMinutes", "minutes"]));
        if (minutes) duration = minutes * 60 * 1000;
    }
    return duration;
}

function monthlyDuration(resetAt) {
    if (resetAt === null) return null;
    var reset = new Date(resetAt);
    if (isNaN(reset.getTime())) return null;
    var year = reset.getUTCFullYear();
    var month = reset.getUTCMonth();
    var day = reset.getUTCDate();
    var hour = reset.getUTCHours();
    var minute = reset.getUTCMinutes();
    var second = reset.getUTCSeconds();
    var millisecond = reset.getUTCMilliseconds();
    var previousMonth = month - 1;
    var previousYear = year;
    if (previousMonth < 0) {
        previousMonth = 11;
        previousYear -= 1;
    }
    var lastDay = new Date(Date.UTC(previousYear, previousMonth + 1, 0)).getUTCDate();
    var previous = Date.UTC(previousYear, previousMonth, Math.min(day, lastDay), hour, minute, second, millisecond);
    var duration = reset.getTime() - previous;
    return duration > 0 ? duration : null;
}

function isMonthly(key, label, id) {
    var marker = (String(key || "") + " " + String(label || "") + " " + String(id || "")).toLowerCase();
    return marker.indexOf("month") >= 0 || marker.indexOf("monthly") >= 0;
}

function expectedPercent(resetAt, durationMs, nowMs) {
    if (resetAt === null || !durationMs) return null;
    var start = resetAt - durationMs;
    return clampPercent(((nowMs - start) / durationMs) * 100);
}

function makeWindow(label, percent, resetAt, durationMs, amountText, nowMs, notes) {
    if (percent === null) return null;
    return {
        label: stringValue(label) || "Usage",
        percent: percent,
        resetAt: resetAt,
        durationMs: durationMs,
        expectedPercent: expectedPercent(resetAt, durationMs, nowMs),
        amountText: amountText || null,
        notes: Array.isArray(notes) ? notes : []
    };
}

function addWindow(provider, windowValue) {
    if (!windowValue) return;
    provider.windows.push(windowValue);
}

function relativeReset(resetAt, nowMs) {
    if (resetAt === null) return "unknown";
    var diff = resetAt - nowMs;
    if (Math.abs(diff) < 60000) return "now";
    var future = diff > 0;
    var remaining = Math.abs(diff);
    var days = Math.floor(remaining / DAY_MS);
    remaining -= days * DAY_MS;
    var hours = Math.floor(remaining / HOUR_MS);
    remaining -= hours * HOUR_MS;
    var minutes = Math.floor(remaining / (60 * 1000));
    var parts = [];
    if (days) parts.push(days + "d", hours + "h");
    else if (hours) parts.push(hours + "h", minutes + "m");
    else parts.push(minutes + "m");
    return parts.join("") + (future ? "" : " ago");
}

function windowDetail(windowValue, nowMs) {
    var now = finiteNumber(nowMs);
    if (now === null) now = Date.now();
    var expected = windowValue && windowValue.expectedPercent !== null && finiteNumber(windowValue.expectedPercent) !== null
        ? Math.round(windowValue.expectedPercent) + "%"
        : "unknown";
    var detail = relativeReset(windowValue ? windowValue.resetAt : null, now) + " · expected " + expected;
    if (windowValue && windowValue.amountText) detail += "; " + windowValue.amountText;
    if (windowValue && Array.isArray(windowValue.notes) && windowValue.notes.length) detail += "; note: " + windowValue.notes.join("; ");
    return detail;
}

function savedResetDetails(provider, resetCredits, nowMs) {
    if (!isObject(resetCredits)) return;
    var credits = Array.isArray(resetCredits.credits) ? resetCredits.credits : [];
    var available = finiteNumber(firstValue(resetCredits, ["availableCount", "available"]));
    var availableCredits = [];
    for (var i = 0; i < credits.length; i++) {
        if (!isObject(credits[i])) continue;
        // Banked credits can expire even while redemption is temporarily unavailable.
        var status = stringValue(credits[i].status);
        if (status && status.toLowerCase() !== "available") continue;
        availableCredits.push(credits[i]);
    }
    if (available === null && availableCredits.length) available = availableCredits.length;

    var next = timestamp(firstValue(resetCredits, ["nextExpiresAt", "soonestExpiresAt"]));
    for (var j = 0; j < availableCredits.length; j++) {
        var expires = timestamp(firstValue(availableCredits[j], ["expiresAt", "expires", "resetAt"]));
        if (expires !== null && (next === null || expires < next)) next = expires;
    }
    if (available !== null) {
        var count = formatNumber(available);
        addUnique(provider.details, count + (available === 1 ? " reset" : " resets") + " available" + (next !== null ? " (expires " + relativeReset(next, nowMs) + ")" : ""));
    }
}

function addFetchedDetail(provider, nowMs) {
    if (!provider || timestamp(provider.fetchedAt) === null) return;
    addUnique(provider.details, relativeReset(provider.fetchedAt, nowMs));
}




function addOmpAccountWarnings(root, warnings) {
    var groups = [{ key: "accountsWithoutUsage", label: "account without usage" }, { key: "disabledCredentials", label: "disabled credential" }];
    for (var i = 0; i < groups.length; i++) {
        var group = groups[i];
        if (root[group.key] === undefined) continue;
        if (!Array.isArray(root[group.key])) throw new Error("OMP " + group.key + " must be an array");
        for (var j = 0; j < root[group.key].length; j++) {
            var item = root[group.key][j];
            if (isObject(item)) {
                var detail = firstValue(item, ["provider", "email", "account", "reason", "message"]);
                addUnique(warnings, group.label + (detail ? ": " + String(detail) : ""));
            } else if (item !== null && item !== undefined) {
                addUnique(warnings, group.label + ": " + String(item));
            }
        }
    }
}
function normalizeOmp(root, nowMs, warnings) {
    if (!isObject(root) || !Array.isArray(root.reports)) throw new Error("OMP payload must contain a reports array");
    addOmpAccountWarnings(root, warnings);
    var providers = [];
    var generated = timestamp(root.generatedAt);
    for (var i = 0; i < root.reports.length; i++) {
        var report = root.reports[i];
        if (!isObject(report)) throw new Error("OMP report must be an object");
        var rawName = stringValue(report.provider);
        if (!rawName) throw new Error("OMP report is missing provider");
        var metadata = isObject(report.metadata) ? report.metadata : {};
        var fetchedAt = timestamp(report.fetchedAt);
        if (fetchedAt === null) fetchedAt = generated !== null ? generated : nowMs;
        var provider = newProvider(rawName, providerIdentity(report, null, metadata), providerPlan(report, null, metadata), fetchedAt);
        addNotes(provider, report.notes, "");
        var reportError = errorMessage(report.error);
        if (report.status && String(report.status).toLowerCase() !== "ok") addUnique(warnings, provider.name + ": status " + String(report.status));
        if (report.limits !== undefined && !Array.isArray(report.limits)) throw new Error("OMP report limits must be an array");
        var limits = Array.isArray(report.limits) ? report.limits : [];
        for (var j = 0; j < limits.length; j++) {
            var limit = limits[j];
            if (!isObject(limit)) throw new Error("OMP limit must be an object");
            var windowObject = isObject(limit.window) ? limit.window : {};
            var amount = isObject(limit.amount) ? limit.amount : {};
            var label = firstValue(windowObject, ["label"]) || firstValue(limit, ["label"]) || firstValue(limit.scope, ["windowId"]) || firstValue(limit, ["id"]);
            var limitNotes = addNotes(provider, limit.notes, label);
            var resetAt = timestamp(firstValue(windowObject, ["resetsAt", "resetAt"]) || firstValue(limit, ["resetsAt", "resetAt"]));
            var duration = durationFor(windowObject, limit);
            if (!duration && isMonthly(firstValue(limit, ["id"]), label, firstValue(windowObject, ["id"]))) duration = monthlyDuration(resetAt);
            var percent = percentFromAmount(amount);
            var amountText = amountTextFor(amount);
            addOmpMonetaryDetail(provider, amount, label);
            addWindow(provider, makeWindow(label, percent, resetAt, duration, amountText, nowMs, limitNotes));
            if (percent === null && amount && Object.keys(amount).length) addUnique(warnings, provider.name + ": ignored unusable percentage for " + (label || "window"));
            if (limit.status && String(limit.status).toLowerCase() !== "ok") addUnique(warnings, provider.name + ": " + (label || "window") + " status " + String(limit.status));
        }
        savedResetDetails(provider, report.resetCredits, nowMs);
        addFetchedDetail(provider, nowMs);
        if (reportError) {
            provider.error = reportError;
            addUnique(warnings, provider.name + ": " + reportError);
        }
        providers.push(provider);
    }
    return providers;
}

function codexWindowPercent(value) {
    if (!isObject(value)) return null;
    var percent = percentFromAmount(value);
    if (percent !== null) return percent;
    var direct = firstValue(value, ["usedPercent", "percent", "usagePercent"]);
    if (direct !== null) return actualPercent(direct);
    var fraction = firstValue(value, ["usedFraction", "usageFraction"]);
    return fraction === null ? null : percentFromFraction(fraction);
}

function codexWindowLabel(key, value, rateLabels) {
    var label = isObject(value) ? firstValue(value, ["label", "name"]) : null;
    if (!label && isObject(rateLabels) && rateLabels[key]) label = rateLabels[key];
    if (!label) {
        var duration = positiveNumber(firstValue(value, ["durationMs"]));
        var minutes = positiveNumber(firstValue(value, ["windowMinutes", "minutes"]));
        if (!minutes && duration) minutes = duration / (60 * 1000);
        if (minutes && minutes <= 24 * 60) label = "Session";
        else if (minutes && minutes <= 8 * 24 * 60) label = "Weekly";
    }
    if (!label) {
        var lower = String(key || "").toLowerCase();
        if (lower === "primary" || lower === "session") label = "Session";
        else if (lower === "secondary" || lower === "weekly") label = "Weekly";
        else if (lower === "tertiary" || lower === "monthly") label = "Monthly";
        else label = key;
    }
    return label;
}

function normalizeCodexReport(report, nowMs, warnings) {
    if (!isObject(report)) throw new Error("CodexBar report must be an object");
    var usage = isObject(report.usage) ? report.usage : {};
    var identity = providerIdentity(report, usage, {});
    var plan = providerPlan(report, usage, {});
    var rawName = stringValue(report.provider) || stringValue(firstValue(usage, ["provider", "providerID"])) || "Unknown";
    var fetchedAt = timestamp(firstValue(usage, ["updatedAt", "fetchedAt"])) || timestamp(firstValue(report, ["updatedAt", "fetchedAt"])) || nowMs;
    var provider = newProvider(rawName, identity, plan, fetchedAt);
    var reportError = errorMessage(report.error);
    var rateLabels = report.rateWindowLabels;
    var windowsObject = isObject(usage.windows) ? usage.windows : usage;
    var handled = {};
    var keys = ["primary", "secondary", "tertiary", "session", "weekly", "monthly"];
    for (var i = 0; i < keys.length; i++) {
        var key = keys[i];
        if (!own(windowsObject, key) || !isObject(windowsObject[key])) continue;
        handled[key] = true;
        appendCodexWindow(provider, key, windowsObject[key], rateLabels, nowMs, warnings);
    }
    if (Array.isArray(usage.windows)) {
        for (var wi = 0; wi < usage.windows.length; wi++) {
            if (isObject(usage.windows[wi])) appendCodexWindow(provider, String(wi), usage.windows[wi], rateLabels, nowMs, warnings);
        }
    }
    // Some providers expose only a weekly object, with no primary/session key.
    for (var key2 in windowsObject) {
        if (!own(windowsObject, key2) || handled[key2] || key2 === "identity" || key2 === "updatedAt" || key2 === "windows") continue;
        if (!isObject(windowsObject[key2])) continue;
        if (isWindowLike(windowsObject[key2])) appendCodexWindow(provider, key2, windowsObject[key2], rateLabels, nowMs, warnings);
    }

    addCodexDetails(provider, report, usage, nowMs);
    addFetchedDetail(provider, nowMs);
    if (reportError) {
        provider.error = reportError;
        addUnique(warnings, provider.name + ": " + reportError);
    }
    return provider;
}

function isWindowLike(value) {
    return firstValue(value, ["usedPercent", "percent", "used", "limit", "usedFraction", "remainingFraction", "windowMinutes", "resetsAt", "resetAt", "durationMs"]) !== null;
}

function appendCodexWindow(provider, key, value, rateLabels, nowMs, warnings) {
    var label = codexWindowLabel(key, value, rateLabels);
    var resetAt = timestamp(firstValue(value, ["resetsAt", "resetAt"]));
    var duration = durationFor(value, value);
    if (!duration && isMonthly(key, label, firstValue(value, ["id"]))) duration = monthlyDuration(resetAt);
    var percent = codexWindowPercent(value);
    var amountText = amountTextFor(value);
    addWindow(provider, makeWindow(label, percent, resetAt, duration, amountText, nowMs));
    if (percent === null) addUnique(warnings, provider.name + ": ignored unusable percentage for " + label);
}

function addCodexDetails(provider, report, usage, nowMs) {
    if (Array.isArray(usage.details)) {
        for (var i = 0; i < usage.details.length; i++) {
            var section = usage.details[i];
            if (!isObject(section)) continue;
            var title = stringValue(section.title);
            if (Array.isArray(section.rows)) {
                for (var j = 0; j < section.rows.length; j++) {
                    var row = section.rows[j];
                    if (!isObject(row)) continue;
                    var rowLabel = stringValue(row.label) || "Detail";
                    var rowValue = row.value === null || row.value === undefined ? "" : String(row.value);
                    var secondary = row.secondaryValue === null || row.secondaryValue === undefined ? "" : String(row.secondaryValue);
                    var detail = (title ? title + ": " : "") + rowLabel + (rowValue ? ": " + rowValue : "") + (secondary ? " (" + secondary + ")" : "");
                    addUnique(provider.details, detail);
                }
            }
        }
    }
    if (isObject(usage.credits)) {
        var remaining = finiteNumber(usage.credits.remaining);
        if (remaining !== null) addUnique(provider.details, "Credits remaining: " + formatNumber(remaining));
    }
    if (isObject(usage.providerCost) && String(usage.providerCost.currencyCode || "").toLowerCase() === "usd") {
        var balance = finiteNumber(usage.providerCost.balance);
        if (balance !== null) addUnique(provider.details, "Provider credits available: $" + formatNumber(balance));
    }
    savedResetDetails(provider, report.resetCredits, nowMs);
}

function normalizeCodexBar(root, nowMs, warnings) {
    var reports = Array.isArray(root) ? root : [root];
    if (!reports.length) return [];
    var providers = [];
    for (var i = 0; i < reports.length; i++) {
        var report = reports[i];
        if (!isObject(report)) throw new Error("CodexBar payload entries must be objects");
        if (!report.error && !report.usage) throw new Error("CodexBar report is missing usage or error");
        providers.push(normalizeCodexReport(report, nowMs, warnings));
    }
    return providers;
}

function normalize(text, backend, nowMs) {
    if (typeof text !== "string") throw new Error("Usage payload must be JSON text");
    var root;
    try {
        root = JSON.parse(text);
    } catch (error) {
        throw new Error("Invalid usage JSON: " + error.message);
    }
    var now = finiteNumber(nowMs);
    if (now === null) now = Date.now();
    var selected = stringValue(backend);
    if (selected) selected = selected.toLowerCase();
    if (!selected || selected === "auto") {
        selected = isObject(root) && Array.isArray(root.reports) ? "omp" : "codexbar";
    }
    var warnings = [];
    var providers = selected === "omp" ? normalizeOmp(root, now, warnings) : selected === "codexbar" ? normalizeCodexBar(root, now, warnings) : null;
    if (!providers) throw new Error("Unknown usage backend: " + backend);
    return { providers: providers, warnings: warnings };
}

function chooseTop(providers) {
    if (!Array.isArray(providers)) return null;
    var candidates = [];
    for (var i = 0; i < providers.length; i++) {
        var provider = providers[i];
        if (!isObject(provider) || !Array.isArray(provider.windows)) continue;
        var usable = [];
        for (var j = 0; j < provider.windows.length; j++) {
            var windowValue = provider.windows[j];
            var percent = actualPercent(windowValue && windowValue.percent);
            if (percent === null) continue;
            usable.push({ window: windowValue, percent: percent });
        }
        if (!usable.length) continue;
        var session = usable.filter(function (entry) {
            var duration = positiveNumber(entry.window.durationMs);
            var label = String(entry.window.label || "").toLowerCase();
            return (duration !== null && duration <= DAY_MS) || label.indexOf("session") >= 0 || label.indexOf("hour") >= 0;
        });
        var weekly = usable.filter(function (entry) {
            var duration = positiveNumber(entry.window.durationMs);
            var label = String(entry.window.label || "").toLowerCase();
            return (duration !== null && duration > DAY_MS && duration <= 8 * DAY_MS) || label.indexOf("week") >= 0;
        });
        var pool = session.length ? session : weekly.length ? weekly : usable;
        pool.sort(function (a, b) {
            var ad = positiveNumber(a.window.durationMs) || Number.MAX_VALUE;
            var bd = positiveNumber(b.window.durationMs) || Number.MAX_VALUE;
            return ad - bd;
        });
        candidates.push({ provider: provider, window: pool[0].window, percent: pool[0].percent });
    }
    if (!candidates.length) return null;
    var top = candidates[0];
    for (var k = 1; k < candidates.length; k++) if (candidates[k].percent > top.percent) top = candidates[k];
    return { name: top.provider.name, label: top.window.label, percent: top.percent };
}
