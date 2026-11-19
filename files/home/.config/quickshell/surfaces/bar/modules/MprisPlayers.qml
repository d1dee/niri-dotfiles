pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import Quickshell.Services.Mpris
import qs
import qs.services
import qs.components
import "../../../lib/ColorUtils.js" as ColorUtils
import "../../../lib/StringUtils.js" as StringUtils
import "../../../lib/AppUtils.js" as AppUtils

BarModule {
    id: root
    name: "mprisPlayers"

    baseWidth: Theme.sizes.barModuleBaseHeight + 28
    expandedWidth: 520
    expandedHeight: MprisService.players.length > 1 ? 274 : 220
    enableClickToExpand: !isExpanded
    onRightButtonClicked: MprisService.players[MprisService.bestPlayerIndex].togglePlaying()

    initialContent: Item {
        MaterialSymbol {
            iconName: MprisService.players.length > 0 ? (MprisService.isAnyPlaying ? "pause" : "play_arrow") : "music_note"
            opacity: MprisService.players.length === 0 ? 0.35 : 1
            anchors.centerIn: parent
            filled: false
            iconSize: MprisService.isAnyPlaying || MprisService.players.length === 0 ? 28 : 34
        }
    }

    expandedContent: Item {
        id: expandedContentItem
        Component.onCompleted: forceActiveFocus()

        property int focusedPlayerIndex: MprisService.bestPlayerIndex
        property var focusedPlayer: MprisService.players.length > 0 ? MprisService.players[focusedPlayerIndex] : null
        property var playerPlaceholder: [
            {
                "isPlaceholder": true,
                "identity": "Placeholder"
            }
        ]

        Keys.onPressed: event => {
            const count = MprisService.players.length;
            if (count === 0)
                return;

            if (event.key === Qt.Key_Tab) {
                expandedContentItem.focusedPlayerIndex = Math.min((expandedContentItem.focusedPlayerIndex + 1), count - 1);
                event.accepted = true;
            } else if (event.key === Qt.Key_Backtab) {
                expandedContentItem.focusedPlayerIndex = Math.max((expandedContentItem.focusedPlayerIndex - 1), 0);
                event.accepted = true;
            } else if (event.key === Qt.Key_Space) {
                if (expandedContentItem.focusedPlayer && expandedContentItem.focusedPlayer.canTogglePlaying) {
                    MprisService.prevPlayingPlayers = [];
                    expandedContentItem.focusedPlayer.togglePlaying();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_L) {
                if (expandedContentItem.focusedPlayer && expandedContentItem.focusedPlayer.canGoNext) {
                    MprisService.prevPlayingPlayers = [];
                    expandedContentItem.focusedPlayer.next();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_H) {
                if (expandedContentItem.focusedPlayer && expandedContentItem.focusedPlayer.canGoPrevious) {
                    MprisService.prevPlayingPlayers = [];
                    expandedContentItem.focusedPlayer.previous();
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_S) {
                if (expandedContentItem.focusedPlayer && expandedContentItem.focusedPlayer.shuffleSupported) {
                    expandedContentItem.focusedPlayer.shuffle = !expandedContentItem.focusedPlayer.shuffle;
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_F) {
                if (expandedContentItem.focusedPlayer) {
                    NiriService.focusApp(expandedContentItem.focusedPlayer.desktopEntry);
                    GlobalStates.expandedBarModule = "";
                    if (expandedContentItem.focusedPlayer.canRaise) {
                        expandedContentItem.focusedPlayer.raise();
                    }
                }
                event.accepted = true;
            } else if (event.key === Qt.Key_R) {
                if (expandedContentItem.focusedPlayer) {
                    if (expandedContentItem.focusedPlayer.loopState === MprisLoopState.None) {
                        expandedContentItem.focusedPlayer.loopState = MprisLoopState.Playlist;
                    } else if (expandedContentItem.focusedPlayer.loopState === MprisLoopState.Playlist) {
                        expandedContentItem.focusedPlayer.loopState = MprisLoopState.Track;
                    } else {
                        expandedContentItem.focusedPlayer.loopState = MprisLoopState.None;
                    }
                }
                event.accepted = true;
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: mouse => mouse.accepted = false
        }

        ColumnLayout {
            id: mainColumn
            anchors.fill: parent
            anchors.margins: 8
            spacing: 8
            clip: true

            StyledSelector {
                id: playerSelector
                Layout.fillWidth: true
                Layout.preferredHeight: opacity * 44
                Layout.alignment: Qt.AlignTop
                entries: MprisService.players
                displayText: entry => entry ? entry.identity : ""
                currentIndex: expandedContentItem.focusedPlayerIndex
                onClicked: expandedContentItem.focusedPlayerIndex = currentIndex
                opacity: MprisService.players.length > 1 ? 1 : 0
                visible: playerSelector.opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: Theme.animations.duration.normal
                        easing.type: Theme.animations.easing.outCirc
                    }
                }

                Binding {
                    target: playerSelector
                    property: "currentIndex"
                    value: expandedContentItem.focusedPlayerIndex
                }
            }

            StyledClippingRectangle {
                id: swipeZone
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.alignment: Qt.AlignBottom
                baseRadius: Theme.rounding.large
                color: "transparent"

                SwipeView {
                    id: swipeable
                    anchors.fill: parent
                    spacing: 16
                    currentIndex: expandedContentItem.focusedPlayerIndex
                    Component.onCompleted: contentItem.highlightMoveDuration = 300
                    onCurrentIndexChanged: expandedContentItem.focusedPlayerIndex = currentIndex
                    interactive: true
                    clip: true

                    Repeater {
                        model: ScriptModel {
                          values: MprisService.players.length > 0 ? MprisService.players : expandedContentItem.playerPlaceholder
                          objectProp: "identity"
                          comparisonMode: ObjectComparison.Identity
                        }

                        StyledRectangle {
                            id: currentPlayer
                            required property int index
                            required property var modelData

                            property var player: modelData
                            property bool isVisible: swipeable.currentIndex === index
                            property var mprisJson: MprisService.json[playerDbusName]
                            property string playerDbusName: (player.dbusName ?? "").replace("org.mpris.MediaPlayer2.", "")
                            property string playerArtPath: (mprisJson?.localPath || player?.trackArtUrl) ?? ""
                            property bool isPlaceholder: player.isPlaceholder ?? false
                            property bool showVolumeIndicator: false
                            property bool haveMprisVolume: (player?.volumeSupported && player?.canControl && !isNaN(Number(player?.volume))) ?? false
                            property var stream: AudioService.streams.filter(s => {
                                var a = player.identity.toLowerCase(), b = s.name.toLowerCase();
                                return a.includes(b) || b.includes(a);
                            })[0] || null
                            property real currentVolume: haveMprisVolume ? player.volume : (stream ? stream.audio.volume : 0)

                            color: "transparent"
                            baseRadius: Theme.rounding.large

                            MouseArea {
                                visible: !currentPlayer.isPlaceholder
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    NiriService.focusApp(currentPlayer.player.desktopEntry);
                                    GlobalStates.expandedBarModule = "";
                                    if (currentPlayer.player.canRaise)
                                        currentPlayer.player.raise();
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 8

                                StyledClippingRectangle {
                                    Layout.preferredWidth: parent.height
                                    Layout.preferredHeight: parent.height
                                    Layout.alignment: Qt.AlignVCenter
                                    baseRadius: currentPlayer.radius - parent.anchors.margins + 2
                                    color: trackArtContainerImage.visible ? "transparent" : Theme.colors.color4
                                    border.width: trackArtContainerImage.visible ? 1 : 0
                                    border.color: ColorUtils.transparentize(Theme.colors.white, 0.125)
                                    shadow: true
                                    forceShadow: true

                                    Image {
                                        id: trackArtContainerImage
                                        anchors.fill: parent
                                        source: Qt.resolvedUrl(currentPlayer.playerArtPath)
                                        visible: status === Image.Ready
                                        cache: true
                                        asynchronous: false
                                        fillMode: Image.PreserveAspectCrop
                                    }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        iconSize: 148
                                        iconName: "music_note"
                                        color: Theme.colors.onPrimary
                                        visible: !trackArtContainerImage.visible
                                    }

                                    StyledRectangle {
                                        anchors.fill: parent
                                        baseRadius: currentPlayer.radius - 12 + 2 + 1
                                        color: "transparent"
                                        border.width: 1
                                        border.color: "#11FFFFFF"
                                        visible: trackArtContainerImage.visible
                                    }
                                }

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true

                                    // Title + Artist
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        StyledText {
                                            visible: currentPlayer.isPlaceholder
                                            text: "No media playing"
                                            font.pixelSize: Theme.fontPixelSizes.huge
                                            font.family: Theme.fontFamilies.text
                                            font.weight: Font.DemiBold
                                            horizontalAlignment: Text.AlignHCenter
                                            Layout.fillWidth: true
                                            opacity: 0.3
                                        }

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: titleText1.font.pixelSize
                                            visible: !currentPlayer.isPlaceholder
                                            clip: true

                                            Row {
                                                id: marqueeRow
                                                property bool needsMarquee: titleText1.contentWidth > parent.width
                                                property real marqueeOffset: 0
                                                x: needsMarquee ? -marqueeOffset : 0
                                                anchors.verticalCenter: parent.verticalCenter
                                                spacing: 40

                                                StyledText {
                                                    id: titleText1
                                                    text: currentPlayer.player.trackTitle || "Unknown Title"
                                                    font.pixelSize: Theme.fontPixelSizes.huge
                                                    font.family: Theme.fontFamilies.text
                                                    font.weight: Font.DemiBold
                                                    horizontalAlignment: Text.AlignLeft
                                                }

                                                StyledText {
                                                    text: titleText1.text
                                                    font: titleText1.font
                                                    horizontalAlignment: Text.AlignLeft
                                                    visible: marqueeRow.needsMarquee
                                                }

                                                SequentialAnimation {
                                                    running: currentPlayer.isVisible && marqueeRow.needsMarquee
                                                    loops: Animation.Infinite
                                                    onRunningChanged: if (!running)
                                                        marqueeRow.marqueeOffset = 0
                                                    PauseAnimation {
                                                        duration: Theme.animations.duration.veryLong
                                                    }
                                                    NumberAnimation {
                                                        target: marqueeRow
                                                        property: "marqueeOffset"
                                                        from: 0
                                                        to: titleText1.contentWidth + marqueeRow.spacing
                                                        duration: (titleText1.contentWidth + marqueeRow.spacing) * 30
                                                        easing.type: Theme.animations.easing.linear
                                                    }
                                                }
                                            }
                                        }

                                        StyledText {
                                            visible: !currentPlayer.isPlaceholder
                                            text: currentPlayer.player.trackArtist || "Unknown Artist"
                                            font.pixelSize: Theme.fontPixelSizes.normal
                                            font.weight: Font.Normal
                                            font.family: Theme.fontFamilies.text
                                            color: Theme.colors.textPrimary
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignLeft
                                            Layout.fillWidth: true
                                        }

                                        Item {
                                            Layout.fillHeight: !currentPlayer.isPlaceholder
                                        }
                                    }

                                    // Progress bar + times
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        visible: !currentPlayer.isPlaceholder
                                        spacing: 6

                                        LinearProgressBar {
                                            id: progressSlider
                                            value: currentPlayer.player.length > 0 && currentPlayer.player.position <= currentPlayer.player.length ? currentPlayer.player.position / currentPlayer.player.length : 0
                                            enableBorder: true
                                            enableAnimation: false
                                            fillColor: Theme.colors.white
                                            backgroundColor: ColorUtils.transparentize(Theme.colors.white, 0.125)
                                            enableClick: true
                                            onClicked: val => currentPlayer.player.position = val * currentPlayer.player.length
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 11

                                            Timer {
                                                interval: 1000
                                                running: currentPlayer.isVisible && (currentPlayer.player.playbackState ?? -1) === MprisPlaybackState.Playing
                                                repeat: true
                                                onTriggered: if (currentPlayer.player.canSeek && currentPlayer.player.positionSupported) {
                                                    progressSlider.value = currentPlayer.player.position / currentPlayer.player.length;
                                                    positionText.text = StringUtils.formatPlayerTime(currentPlayer.player.position);
                                                }
                                            }
                                        }

                                        RowLayout {
                                            id: positionRow
                                            Layout.fillWidth: true

                                            StyledText {
                                                id: positionText
                                                text: StringUtils.formatPlayerTime(currentPlayer.player.position)
                                                font.family: Theme.fontFamilies.runde
                                                font.pixelSize: Theme.fontPixelSizes.smaller
                                                font.weight: Font.Medium
                                                opacity: 0.40
                                            }
                                            Item {
                                                Layout.fillWidth: true
                                            }
                                            MaterialSymbol {
                                              visible: currentPlayer.player.length >= 460800 // 128 hours
                                              iconName: "all_inclusive"
                                              weight: 200
                                              opacity: 0.40
                                            }
                                            StyledText {
                                                text: StringUtils.formatPlayerTime(currentPlayer.player.length)
                                                visible: currentPlayer.player.length < 460800 // 128 hours
                                                font.family: Theme.fontFamilies.runde
                                                font.pixelSize: Theme.fontPixelSizes.smaller
                                                font.weight: Font.Medium
                                                opacity: 0.40
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.preferredHeight: 0
                                    }

                                    // Control buttons + Skip buttons
                                    RowLayout {
                                        visible: !currentPlayer.isPlaceholder
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignHCenter
                                        spacing: 4

                                        PlayerButton {
                                            Layout.alignment: Qt.AlignVCenter
                                            enabled: currentPlayer.player.canGoPrevious ?? false
                                            iconName: "skip_previous"
                                            iconSize: 34
                                            implicitWidth: iconSize + 2
                                            implicitHeight: iconSize + 2
                                            active: true
                                            onClicked: {
                                                currentPlayer.player.previous();
                                                MprisService.prevPlayingPlayers = [];
                                            }
                                        }

                                        PlayerButton {
                                            enabled: (currentPlayer.player.canControl && currentPlayer.player.shuffleSupported) ?? false
                                            iconName: "shuffle"
                                            iconSize: 36
                                            implicitWidth: iconSize + 8
                                            implicitHeight: iconSize + 8
                                            active: currentPlayer.player.shuffle ?? false
                                            onClicked: {
                                                currentPlayer.player.shuffle = !currentPlayer.player.shuffle;
                                                MprisService.prevPlayingPlayers = [];
                                            }
                                        }

                                        PlayerButton {
                                            enabled: currentPlayer.player.canTogglePlaying ?? false
                                            iconName: (currentPlayer.player.isPlaying ?? false) ? "pause" : "play_arrow"
                                            iconSize: 52
                                            active: true
                                            onClicked: {
                                                currentPlayer.player.togglePlaying();
                                                MprisService.prevPlayingPlayers = [];
                                            }
                                        }

                                        PlayerButton {
                                            enabled: (currentPlayer.player?.canControl && currentPlayer.player?.loopSupported) ?? false
                                            iconName: currentPlayer.player.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                                            iconSize: 36
                                            implicitWidth: iconSize + 8
                                            implicitHeight: iconSize + 8
                                            active: (currentPlayer.player.loopState ?? MprisLoopState.None) !== MprisLoopState.None
                                            onClicked: {
                                                currentPlayer.player.loopState = currentPlayer.player.loopState === MprisLoopState.None ? MprisLoopState.Playlist : currentPlayer.player.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None;
                                                MprisService.prevPlayingPlayers = [];
                                            }
                                        }

                                        PlayerButton {
                                            Layout.alignment: Qt.AlignVCenter
                                            enabled: currentPlayer.player.canGoNext ?? false
                                            iconSize: 34
                                            implicitWidth: iconSize + 2
                                            implicitHeight: iconSize + 2
                                            iconName: "skip_next"
                                            active: true
                                            onClicked: {
                                                currentPlayer.player.next();
                                                MprisService.prevPlayingPlayers = [];
                                            }
                                        }
                                    }
                                }
                            }

                            StyledIcon {
                                visible: !currentPlayer.isPlaceholder
                                iconName: AppUtils.getAppIcon(currentPlayer.player.identity, [...new Set(DesktopEntries.applications.values)], currentPlayer.playerDbusName.split("."))
                                iconSize: 24
                                useIconTheme: true
                                placeHolder: "applications-system"
                                replacements: Object.assign({}, currentPlayer.player.identity === "Mozilla zen" && {
                                    "firefox": "zen-browser"
                                })
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: 8
                            }
                        }
                    }
                }
            }
        }
    }

    component PlayerButton: StyledIconButton {
        property bool active: false
        implicitWidth: iconSize
        implicitHeight: iconSize
        showBackground: false
        inactiveOpacity: !enabled ? 0.15 : active ? 1 : 0.5
        backgroundColor: active ? Theme.colors.gray6 : Theme.colors.gray4
        color: active ? Theme.colors.white : Theme.colors.gray10
        backgroundTransparency: 0.40
    }
}
