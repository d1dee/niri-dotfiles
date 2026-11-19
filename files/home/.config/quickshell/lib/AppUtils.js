.pragma library
.import "FuzzyFilter.js" as FuzzyFilter

/**
 * Finds an application icon based on a query string by searching through desktop entries.
 * @param {string} query - The search query (e.g., app name, process name, or stream name).
 * @param {Array} apps - The list of application desktop entries to search in.
 * @param {string[]} [alternatives=[]] - Alternative strings to try if the primary query fails.
 * @returns {string} The icon name found, or the original query if no match is found.
 */
function getAppIcon(query, apps, alternatives = []) {
    if (!query) return "";
    if (!apps || apps.length === 0) return query;

    const searchFields = ['name', 'id', 'genericName'];
    const invalidPattern = /^[^a-zA-Z0-9]+$/;

    for (const q of [query, ...alternatives]) {
        if (!q || invalidPattern.test(q)) continue;

        const normalized = normalizeAppId(q);
        const exact = apps.find(app => normalizeAppId(app.id) === normalized || normalizeAppId(app.startupClass) === normalized);
        if (exact?.icon) return exact.icon;

        const filtered = FuzzyFilter.search(q, apps, {
            threshold: 0,
            limit: 1,
            all: false,
            keys: searchFields,
            pick: "raw"
        });

        const icon = filtered[0]?.obj?.icon;
        if (icon) return icon;
    }

    return query;
}

function normalizeAppId(query) {
    return String(query ?? "").trim().replace(/\.desktop$/i, "").toLowerCase();
}

// Prefer the focused window when an application owns several windows.
function findWindowForApp(app, windows) {
    if (!app || !windows) return null;
    const ids = [normalizeAppId(app.startupClass), normalizeAppId(app.id)].filter(Boolean);
    const matches = windows.filter(window => ids.includes(normalizeAppId(window.app_id)));
    return matches.find(window => window.is_focused) ?? matches[0] ?? null;
}
