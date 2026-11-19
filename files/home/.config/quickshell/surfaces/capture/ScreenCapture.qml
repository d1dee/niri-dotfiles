pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "../../lib/FileUtils.js" as FileUtils

Scope {
    id: root

    property string pendingScreenshotPath: ""
    property string pendingMode: ""

    function startRegionCapture(toTemp, path, mode = "snapshot") {
        if (captureProcess.running || processingProcess.running || GlobalCache.loadLockScreen)
            return;
        if (!["snapshot", "ocr", "lens"].includes(mode)) {
            Quickshell.execDetached(["notify-send", "Capture mode unavailable", "Choose snapshot, OCR, or Lens. Region recording requires OBS with a crop filter."]);
            return;
        }
        const directory = path || (toTemp || mode !== "snapshot" ? Paths.screenshotTempDir : Paths.screenshotDir);
        root.pendingScreenshotPath = FileUtils.trimFileProtocol(`${directory}/${generateFilename()}`);
        root.pendingMode = mode;
        GlobalStates.showScreenCapture = true;
        // Native selection copies only the confirmed selection, never a full-output preview.
        captureProcess.command = ["bash", FileUtils.trimFileProtocol(Paths.scripts) + "/niri_screenshot.sh", "region", root.pendingScreenshotPath];
        captureProcess.running = true;
    }

    function generateFilename(): string {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH'h'mm'm'ss's'zzz") + ".png";
    }

    function sanitizePath(path: string): string {
        if (!path)
            return path;
        let cleaned = path.replace(/^["']|["']$/g, '');
        if (cleaned.startsWith('~/'))
            cleaned = (Quickshell.env("HOME") || "") + cleaned.substring(1);
        return cleaned;
    }

    function captureMonitor(customPath: string): void {
        if (captureProcess.running || processingProcess.running || GlobalCache.loadLockScreen)
            return;
        root.pendingScreenshotPath = FileUtils.trimFileProtocol(customPath || `${Paths.screenshotDir}/${generateFilename()}`);
        root.pendingMode = "snapshot";
        // This explicitly requested operation captures and copies the complete focused output.
        captureProcess.command = ["bash", FileUtils.trimFileProtocol(Paths.scripts) + "/niri_screenshot.sh", "monitor", root.pendingScreenshotPath];
        captureProcess.running = true;
    }

    function handleScreenshotSuccess(filePath: string): void {
        Quickshell.execDetached(["bash", "-c", 'wl-copy --type image/png < "$1"', "capture-copy", filePath]);
        Quickshell.execDetached(["bash", "-c", 'action=$(notify-send -i "$1" -a Screenshot "Screenshot Taken" "Saved and copied to clipboard" -t 0 -A "open=Open Screenshot"); if [[ "$action" == open ]]; then xdg-open "$1"; fi', "capture-notify", filePath]);
    }

    function finishCapture(exitCode) {
        const image = root.pendingScreenshotPath;
        const mode = root.pendingMode;
        root.pendingScreenshotPath = "";
        root.pendingMode = "";
        GlobalStates.showScreenCapture = false;
        if (exitCode === 2)
            return;
        if (exitCode !== 0) {
            Quickshell.execDetached(["notify-send", "Screenshot failed", "Native niri capture failed. Check the target path and session logs."]);
            return;
        }
        if (mode === "snapshot") {
            root.handleScreenshotSuccess(image);
        } else if (mode === "lens") {
            processingProcess.command = ["bash", FileUtils.trimFileProtocol(Paths.lensScript), image];
            processingProcess.running = true;
        } else if (mode === "ocr") {
            processingProcess.command = ["bash", "-c", 'set -euo pipefail; languages=(); while IFS= read -r lang; do [[ "$lang" =~ ^[a-zA-Z_][a-zA-Z0-9_/-]*$ && "$lang" != osd ]] && languages+=("$lang"); done < <(tesseract --list-langs); ((${#languages[@]})) || exit 1; IFS=+; tesseract "$1" stdout -l "${languages[*]}" | wl-copy; notify-send -a Screenshot "Text extracted" "Copied to clipboard"', "capture-ocr", image];
            processingProcess.running = true;
        }
    }

    Process {
        id: captureProcess
        onExited: (exitCode, exitStatus) => root.finishCapture(exitCode)
    }

    Process {
        id: processingProcess
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0)
                Quickshell.execDetached(["notify-send", "Capture processing failed", "Check Tesseract/OCR languages and Lens dependencies."]);
        }
    }
}
