pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
    id: root

    readonly property string materialSymbol: "colorize"
    property string _currentFormat: "hex"

    signal colorPicked(var colorEntry)

    function pick(format = "hex", delay = 0.2) {
        if (pickerProcess.running || pickerDelay.running)
            return;
        root._currentFormat = format === "rgb" ? "rgb" : "hex";
        pickerDelay.interval = Math.max(0, Number(delay) * 1000 || 0);
        pickerDelay.start();
    }

    Timer {
        id: pickerDelay
        onTriggered: pickerProcess.exec(["niri", "msg", "--json", "pick-color"])
    }

    Process {
        id: pickerProcess
        stdout: StdioCollector {
            onStreamFinished: {
                let picked;
                try {
                    picked = JSON.parse(text);
                } catch (_) {
                    return;
                }
                // A cancelled native picker returns null.
                if (!Array.isArray(picked?.rgb) || picked.rgb.length !== 3 || !picked.rgb.every(c => Number.isFinite(c) && c >= 0 && c <= 1))
                    return;
                const rgb = picked.rgb.map(c => Math.round(c * 255));
                const extracted = root._currentFormat === "rgb" ? rgb.join(", ") : "#" + rgb.map(c => c.toString(16).padStart(2, "0")).join("");
                copyProcess.exec(["wl-copy", extracted]);

                const magickColor = root._getMagickColor(extracted, root._currentFormat);
                const filename = extracted.replace(/[ %#]/g, "_");
                const previewPath = Paths.colorPickerTempDir + "/" + filename + ".png";

                magickProcess.lastExtracted = extracted;
                magickProcess.lastPreviewPath = previewPath;
                magickProcess.exec(["magick", "-size", "64x64", "xc:" + magickColor, previewPath]);

                const hexColor = root._toHex(extracted, root._currentFormat);
                const colorEntry = {
                    color: extracted,
                    hex: hexColor,
                    type: root._currentFormat,
                    timestamp: new Date().getTime()
                };

                const colors = GlobalCache.pickedColors || [];
                colors.push(colorEntry);

                // New reference so pickedColorsChanged fires (reverse() mutates in place).
                GlobalCache.pickedColors = colors.slice().reverse();
                root.colorPicked(colorEntry);
            }
        }
        onExited: (code, status) => {
            if (code !== 0)
                notifyProcess.exec(["notify-send", "Color Picker failed", "Native niri color picking is unavailable. Check niri version and session logs."]);
        }
    }

    Process {
        id: copyProcess
    }

    Process {
        id: magickProcess
        property string lastExtracted
        property string lastPreviewPath
        onExited: {
            notifyProcess.exec(["notify-send", "Color Picked ( " + root._currentFormat + " )", lastExtracted, "-i", lastPreviewPath, "-a", "Color Picker", "-t", "7500"]);
        }
    }

    Process {
        id: notifyProcess
    }

    function _toHex(extracted, format) {
        if (format === "hex")
            return extracted;
        // Raw RGB triplets are not valid QML colors.
        const m = (extracted || "").match(/(\d+),\s*(\d+),\s*(\d+)/);
        if (!m)
            return "";
        const to2 = n => ("0" + Math.max(0, Math.min(255, parseInt(n, 10))).toString(16)).slice(-2);
        return "#" + to2(m[1]) + to2(m[2]) + to2(m[3]);
    }

    function _getMagickColor(color, format) {
        if (format === "hex")
            return color;
        if (format === "rgb")
            return "rgb(" + color + ")";
        return color;
    }
}
