.pragma library

/**
 * Capitalize the first letter of each word
 * @param {string} str
 * @returns {string}
 */
function capitalize(str) {
  if (!str || typeof str !== "string") return "";

  return str
    .split(" ")
    .map(word => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ");
}

/**
 * Safely parses a JSON string, returning a default value if parsing fails.
 * @param {string} jsonString - The JSON string to parse.
 * @param {any} [defaultValue=null] - The value to return if parsing fails.
 * @returns {any} The parsed object or defaultValue.
 */
function safeParse(jsonString, defaultValue = null) {
    if (!jsonString || typeof jsonString !== "string" || jsonString.trim() === "") {
        return defaultValue;
    }
    try {
        return JSON.parse(jsonString);
    } catch (e) {
        return defaultValue;
    }
}

/**
 * Check if a string is a valid URL or domain
 * @param {string} text
 * @returns {boolean}
 */
function isUrl(text) {
    if (!text || typeof text !== "string") return false;
    const urlPattern = /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/i;
    return urlPattern.test(text.trim());
}

/**
 * Highlight a query match inside a string as HTML bold, safe for RichText.
 * Characters like é, ç, &, <, > are properly escaped.
 * @param {string} str - The full string to display
 * @param {string} query - The substring to highlight
 * @returns {string} HTML string with <b>matched</b> portion
 */
function highlightMatch(str, query) {
    if (!str) return "";

    function escapeHtml(s) {
        return s.replace(/&/g, "&amp;")
                .replace(/</g, "&lt;")
                .replace(/>/g, "&gt;");
    }

    if (!query) return escapeHtml(str);

    const idx = str.toLowerCase().indexOf(query.toLowerCase());
    if (idx < 0) return escapeHtml(str);

    const before = escapeHtml(str.slice(0, idx));
    const match  = escapeHtml(str.slice(idx, idx + query.length));
    const after  = escapeHtml(str.slice(idx + query.length));

    return `${before}<b>${match}</b>${after}`;
}

/**
 * Format seconds as M:SS or H:MM:SS
 * @param {number} seconds
 * @returns {string}
 */
function formatPlayerTime(seconds) {
    seconds = Math.floor(seconds);

    const hours = Math.floor(seconds / 3600);
    const minutes = Math.floor((seconds % 3600) / 60);
    const remainingSeconds = seconds % 60;

    if (hours > 0)
        return hours + ":" + String(minutes).padStart(2, "0") + ":" + String(remainingSeconds).padStart(2, "0");

    return minutes + ":" + String(remainingSeconds).padStart(2, "0");
}

/**
 * Check if a character is an emoji
 * @param {string} char
 * @returns {boolean}
 */
function isEmoji(text) {
  if (!text || text.length === 0) return false;

  // Remove variation selectors and zero-width joiners as they're emoji modifiers
  const cleaned = text.replace(/[\uFE00-\uFE0F\u200D]/g, '');

  // Check each codepoint
  for (const char of cleaned) {
    const code = char.codePointAt(0);
    const isEmoji = (
      (code >= 0x1F600 && code <= 0x1F64F) || // Emoticons
      (code >= 0x1F300 && code <= 0x1F5FF) || // Misc Symbols and Pictographs
      (code >= 0x1F680 && code <= 0x1F6FF) || // Transport and Map
      (code >= 0x1F700 && code <= 0x1F77F) || // Alchemical Symbols
      (code >= 0x1F780 && code <= 0x1F7FF) || // Geometric Shapes Extended
      (code >= 0x1F800 && code <= 0x1F8FF) || // Supplemental Arrows-C
      (code >= 0x1F900 && code <= 0x1F9FF) || // Supplemental Symbols and Pictographs
      (code >= 0x1FA00 && code <= 0x1FA6F) || // Chess Symbols
      (code >= 0x1FA70 && code <= 0x1FAFF) || // Symbols and Pictographs Extended-A
      (code >= 0x2600 && code <= 0x26FF) ||   // Misc symbols
      (code >= 0x2700 && code <= 0x27BF) ||   // Dingbats
      (code >= 0x1F1E6 && code <= 0x1F1FF) || // Regional Indicator Symbols (flags)
      (code >= 0x231A && code <= 0x23FF) ||   // Misc Technical (includes some emojis)
      (code >= 0x2B50 && code <= 0x2BFF)      // Misc Symbols (stars, etc)
    );

    if (!isEmoji) return false;
  }

  return true;
}

/**
 * Returns an HTML string with basic token colouring (Gruvbox).
 * Deliberately lightweight — no full grammar, just good-enough highlighting
 * for preview panes.
 * @param {string} code
 * @param {string} mime
 * @returns {string}
 */
function syntaxHighlight(code, mime) {
    if (!code)
        return "";

    // Escape HTML entities first
    function esc(s) {
        return s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
    }

    const escaped = esc(code);

    // Syntax colors
    const C = {
        keyword: "#ff7733",
        string: "#bae67e",
        number: "#ffcc66",
        comment: "#5c6773",
        key: "#5ccfe6",
        bool: "#ffcc66",
        tag: "#ff7733",
        attr: "#ffcc66",
        punct: "#cccac2"
    };

    function wrap(color, text) {
        return `<span style="color:${color}">${text}</span>`;
    }

    function highlightGeneric(s) {
        // strings
        s = s.replace(/(&#39;[^&#]*&#39;|&quot;[^&]*&quot;|`[^`]*`)/g, m => wrap(C.string, m));
        // numbers
        s = s.replace(/\b(\d+\.?\d*)\b/g, (_, n) => wrap(C.number, n));
        // single-line comments (// and #)
        s = s.replace(/(\/\/[^\n]*|#[^\n]*)/g, m => wrap(C.comment, m));
        // common keywords
        const kw = /\b(if|else|for|while|return|function|const|let|var|class|import|export|from|def|in|is|not|and|or|true|false|null|undefined|void|new|this|self|async|await|try|catch|finally|throw|switch|case|break|continue|do|of|type|interface|extends|implements|super|static|public|private|protected|abstract|override|readonly|enum|struct|mod|use|fn|mut|let|impl|trait|where|match|ref|move|dyn|pub|crate|extern|unsafe)\b/g;
        s = s.replace(kw, m => wrap(C.keyword, m));
        return s;
    }

    function highlightJSON(s) {
        // keys
        s = s.replace(/(&quot;[^&]+&quot;)\s*:/g, (_, k) => wrap(C.key, k) + ":");
        // string values
        s = s.replace(/:\s*(&quot;[^&]*&quot;)/g, (full, v) => full.replace(v, wrap(C.string, v)));
        // numbers
        s = s.replace(/:\s*(-?\d+\.?\d*)/g, (full, n) => full.replace(n, wrap(C.number, n)));
        // booleans / null
        s = s.replace(/\b(true|false|null)\b/g, m => wrap(C.bool, m));
        // punctuation
        s = s.replace(/([{}\[\],:])/g, m => wrap(C.punct, m));
        return s;
    }

    function highlightHTML(s) {
        // tags
        s = s.replace(/(&lt;\/?[a-zA-Z][a-zA-Z0-9-]*)/g, m => wrap(C.tag, m));
        s = s.replace(/\/?&gt;/g, m => wrap(C.tag, m));
        // attributes
        s = s.replace(/\s([a-zA-Z-]+)=/g, (full, a) => full.replace(a, wrap(C.attr, a)));
        // string values
        s = s.replace(/(&quot;[^&]*&quot;|&#39;[^&#]*&#39;)/g, m => wrap(C.string, m));
        // comments
        s = s.replace(/(&lt;!--[\s\S]*?--&gt;)/g, m => wrap(C.comment, m));
        return s;
    }

    let highlighted;
    if (mime === "application/json" || mime === "") {
        // try JSON first if content looks like it
        const trimmed = code.trim();
        if (trimmed.startsWith("{") || trimmed.startsWith("[")) {
            highlighted = highlightJSON(escaped);
        } else {
            highlighted = highlightGeneric(escaped);
        }
    } else if (mime === "text/html" || mime === "application/xml") {
        highlighted = highlightHTML(escaped);
    } else {
        highlighted = highlightGeneric(escaped);
    }

    // Preserve newlines and indentation
    return highlighted.replace(/ {2}/g, "&nbsp;&nbsp;").replace(/\t/g, "&nbsp;&nbsp;&nbsp;&nbsp;").replace(/\n/g, "<br/>");
}
