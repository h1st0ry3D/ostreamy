import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

/*
 * Ostreamy: the bar face of ostreamy-cli.
 *
 * The panel does not read the config or talk to Hyprland. It asks the CLI for
 * `state` as JSON and changes the layout with `on`, `off` and `mode`. That keeps
 * one parser for the config, one place that knows the Hyprland rules, and this
 * file free of layout logic.
 *
 * Changing the mode during a stream would rebuild the encoder and stall the
 * video, so the CLI saves the value and applies it after the stream. The panel
 * says so instead of pretending the change took effect.
 */
Panel {
    id: root

    moduleName: "h1st0ry3d.ostreamy"
    ipcTarget: "h1st0ry3d.ostreamy"
    implicitWidth: button.implicitWidth
    implicitHeight: button.implicitHeight

    // -- the CLI ------------------------------------------------------------
    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property var cliCandidates: [
        "/usr/local/bin/ostreamy",
        root.homeDir + "/.local/bin/ostreamy"
    ]
    property string cliPath: ""
    property bool cliMissing: false

    Process {
        id: cliProbe
        running: false
        property int attempt: 0
        stdout: SplitParser { onRead: function(chunk) {} }
        stderr: SplitParser { onRead: function(chunk) {} }
        command: ["/usr/bin/test", "-x", root.cliCandidates[cliProbe.attempt]]

        onExited: function(code) {
            if (code === 0) {
                root.cliPath = root.cliCandidates[cliProbe.attempt]
                root.cliMissing = false
                root.statusIsError = false
                root.statusText = ""
                root.refresh()
                return
            }
            cliProbe.attempt++
            if (cliProbe.attempt < root.cliCandidates.length) {
                cliProbe.command = ["/usr/bin/test", "-x", root.cliCandidates[cliProbe.attempt]]
                cliProbe.running = true
                return
            }
            root.cliMissing = true
            root.statusIsError = true
            root.statusText = "ostreamy is not installed."
            root.statusDetail = "Install ostreamy-cli, then reopen this panel."
        }
    }

    function probe() {
        if (cliProbe.running) return
        cliProbe.attempt = 0
        cliProbe.command = ["/usr/bin/test", "-x", root.cliCandidates[0]]
        cliProbe.running = true
    }

    // -- state --------------------------------------------------------------
    property var loaded: null
    property bool loadedReady: false
    readonly property bool streaming: root.loadedReady && root.loaded
        ? root.loaded.streaming === true : false
    readonly property int modeWidth: root.loadedReady && root.loaded ? Number(root.loaded.width) : 0
    readonly property int modeHeight: root.loadedReady && root.loaded ? Number(root.loaded.height) : 0
    readonly property int frameRate: root.loadedReady && root.loaded ? Number(root.loaded.fps) : 60

    readonly property var resolutions: [
        { w: 1280, h: 800, label: "1280x800", note: "Deck native" },
        { w: 1920, h: 1200, label: "1920x1200", note: "16:10 desktop" }
    ]
    readonly property var frameRates: [30, 40, 45, 60, 80, 90]

    readonly property int outputLimit: 65536
    readonly property int watchdogMs: 10000

    property bool statusIsError: false
    property string statusText: ""
    property string statusDetail: ""

    function refresh() {
        if (root.cliPath === "") return
        stateProcess.buffer = ""
        stateProcess.failure = ""
        stateProcess.command = [root.cliPath, "state"]
        stateProcess.running = true
        stateTimeout.restart()
    }

    Process {
        id: stateProcess
        running: false
        property string buffer: ""
        property string failure: ""
        stdout: SplitParser {
            splitMarker: ""
            onRead: function(chunk) {
                if (stateProcess.buffer.length <= root.outputLimit)
                    stateProcess.buffer += chunk
            }
        }
        stderr: SplitParser { onRead: function(line) { stateProcess.failure = line } }
        onExited: function(code) {
            stateTimeout.stop()
            var text = stateProcess.buffer
            stateProcess.buffer = ""
            if (code !== 0) {
                root.statusIsError = true
                root.statusText = "Could not read the stream state."
                root.statusDetail = stateProcess.failure
                return
            }
            var parsed = null
            try { parsed = JSON.parse(String(text).trim() || "null") } catch (e) { parsed = null }
            if (!parsed) {
                root.statusIsError = true
                root.statusText = "ostreamy printed something this panel does not understand."
                return
            }
            root.loaded = parsed
            root.loadedReady = true
        }
    }

    Timer {
        id: stateTimeout
        interval: root.watchdogMs
        repeat: false
        onTriggered: if (stateProcess.running) stateProcess.signal(15)
    }

    // -- actions ------------------------------------------------------------
    property bool busy: false
    property bool timedOut: false

    function act(args, status) {
        if (root.cliPath === "" || actionProcess.running) return
        root.busy = true
        root.timedOut = false
        root.statusIsError = false
        root.statusDetail = ""
        root.statusText = status
        actionProcess.failure = ""
        actionProcess.command = [root.cliPath].concat(args)
        actionProcess.running = true
        actionTimeout.restart()
    }

    function setLayout(on) {
        root.act([on ? "on" : "off"], on ? "Switching to stream-ready..." : "Restoring the desktop...")
    }

    function toggleLayout() {
        root.setLayout(!root.streaming)
    }

    function setMode(w, h, hz) {
        var note = root.streaming ? "Saved for the next stream: " : "Applying "
        root.act(["mode", w + "x" + h + "@" + hz], note + w + "x" + h + "@" + hz + "...")
    }

    function editConfig() {
        root.act(["edit"], "Opening the config...")
    }

    Process {
        id: actionProcess
        running: false
        property string failure: ""
        stdout: SplitParser { onRead: function(chunk) {} }
        stderr: SplitParser { onRead: function(line) { actionProcess.failure = line } }
        onExited: function(code) {
            actionTimeout.stop()
            root.busy = false
            if (root.timedOut) {
                root.timedOut = false
                root.statusIsError = true
                root.statusText = "ostreamy did not answer in time."
                return
            }
            if (code !== 0) {
                root.statusIsError = true
                root.statusText = "ostreamy refused the command."
                root.statusDetail = actionProcess.failure
                return
            }
            root.statusText = ""
            root.refresh()
        }
    }

    Timer {
        id: actionTimeout
        interval: root.watchdogMs
        repeat: false
        onTriggered: {
            if (!actionProcess.running) return
            root.timedOut = true
            actionProcess.signal(15)
        }
    }

    onOpenedChanged: {
        if (root.opened) {
            if (root.cliMissing) root.probe()
            else root.refresh()
            return
        }
        if (!root.busy && !root.statusIsError) root.statusText = ""
    }

    Component.onCompleted: root.probe()

    // -- bar icon -----------------------------------------------------------
    BarIconButton {
        id: button
        anchors.fill: parent
        bar: root.bar
        // U+F24D is fa-clone in the bar font: two overlapping frames, closest
        // glyph to a picture-in-picture stream target.
        text: "\uf24d"
        tooltipText: root.loadedReady
            ? "Ostreamy: " + root.modeWidth + "x" + root.modeHeight + " at "
              + root.frameRate + " Hz" + (root.streaming ? ", streaming" : ", desktop")
            : "Ostreamy: stream target"
        onPressed: function(button) { root.toggle() }
    }

    // -- panel --------------------------------------------------------------
    KeyboardPanel {
        id: dropdown
        anchorItem: button
        owner: root
        bar: root.bar
        open: root.opened
        focusTarget: keyCatcher
        contentWidth: dropdown.fittedContentWidth(Style.space(340))
        contentHeight: dropdown.fittedContentHeight(col.implicitHeight, Style.space(420))

        PanelKeyCatcher {
            id: keyCatcher
            anchors.fill: parent
            onCloseRequested: root.close()
            onTabRequested: function(direction) { root.switchPanel(direction) }

            Flickable {
                anchors.fill: parent
                contentWidth: width
                contentHeight: col.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                Column {
                    id: col
                    width: parent.width
                    spacing: Style.space(8)
                    topPadding: Style.space(12)
                    bottomPadding: Style.space(12)

                    PanelHero {
                        id: hero
                        width: parent.width
                        title: "Ostreamy"
                        meta: root.loadedReady
                            ? root.modeWidth + "x" + root.modeHeight + " at " + root.frameRate
                              + " Hz, " + (root.streaming ? "streaming" : "desktop")
                            : (root.cliMissing ? "ostreamy-cli is missing" : "Reading stream state...")
                        detail: root.statusText
                        foreground: Color.foreground
                        fontFamily: Style.font.family
                        iconComponent: Component {
                            Text {
                                text: button.text
                                textFormat: Text.PlainText
                                color: root.statusIsError ? "#f44" : hero.foreground
                                font.family: hero.fontFamily
                                font.pixelSize: Style.font.displayLarge
                            }
                        }
                        trailingControl: Component {
                            Button {
                                text: "Edit"
                                bordered: true
                                enabled: root.cliPath !== "" && !root.busy
                                tooltipText: "Edit ~/.config/ostreamy/config.sh"
                                onClicked: root.editConfig()
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        visible: root.statusDetail !== "" && root.statusIsError
                        text: root.statusDetail
                        textFormat: Text.PlainText
                        color: "#f44"
                        font.family: Style.font.family
                        font.pixelSize: Style.font.bodySmall
                        wrapMode: Text.WordWrap
                    }

                    PanelSeparator { foreground: Color.foreground }

                    // Enable / Disable / Toggle, one row, like the other panels.
                    Row {
                        width: parent.width
                        spacing: Style.space(6)
                        readonly property real cellWidth: (width - spacing * 2) / 3

                        Button {
                            width: parent.cellWidth
                            bordered: true
                            text: "Enable"
                            selected: root.streaming
                            enabled: root.cliPath !== "" && !root.busy
                            tooltipText: "Move workspaces to STREAM and mirror the panel"
                            onClicked: root.setLayout(true)
                        }
                        Button {
                            width: parent.cellWidth
                            bordered: true
                            text: "Disable"
                            selected: !root.streaming && root.loadedReady
                            enabled: root.cliPath !== "" && !root.busy
                            tooltipText: "Restore the desktop layout"
                            onClicked: root.setLayout(false)
                        }
                        Button {
                            width: parent.cellWidth
                            bordered: true
                            text: "Toggle"
                            enabled: root.cliPath !== "" && !root.busy
                            tooltipText: "Flip between desktop and stream-ready"
                            onClicked: root.toggleLayout()
                        }
                    }

                    Text {
                        width: parent.width
                        text: "Resolution"
                        textFormat: Text.PlainText
                        color: Util.alpha(Color.foreground, 0.7)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }

                    Row {
                        width: parent.width
                        spacing: Style.space(6)
                        readonly property real cellWidth: (width - spacing) / 2

                        Repeater {
                            model: root.resolutions
                            delegate: Button {
                                required property var modelData
                                width: parent.cellWidth
                                bordered: true
                                selected: root.loadedReady
                                    && root.modeWidth === modelData.w
                                    && root.modeHeight === modelData.h
                                enabled: root.cliPath !== "" && !root.busy
                                text: modelData.label + " · " + modelData.note
                                tooltipText: "Stream at " + modelData.label
                                onClicked: root.setMode(modelData.w, modelData.h, root.frameRate)
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: "Frame rate"
                        textFormat: Text.PlainText
                        color: Util.alpha(Color.foreground, 0.7)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                    }

                    Row {
                        width: parent.width
                        spacing: Style.space(6)
                        readonly property real cellWidth: (width - spacing * 5) / 6

                        Repeater {
                            model: root.frameRates
                            delegate: Button {
                                required property int modelData
                                width: parent.cellWidth
                                bordered: true
                                selected: root.loadedReady && root.frameRate === modelData
                                enabled: root.cliPath !== "" && !root.busy
                                text: String(modelData)
                                tooltipText: "Stream at " + modelData + " Hz"
                                onClicked: root.setMode(root.modeWidth, root.modeHeight, modelData)
                            }
                        }
                    }

                    Text {
                        width: parent.width
                        text: "Changes apply immediately while nothing is streaming. During "
                            + "a stream the value is saved and used by the next session."
                        textFormat: Text.PlainText
                        color: Util.alpha(Color.foreground, 0.7)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                    }

                    Text {
                        width: parent.width
                        visible: root.statusText !== "" && !root.statusIsError
                        text: root.statusText
                        textFormat: Text.PlainText
                        color: Util.alpha(Color.foreground, 0.7)
                        font.family: Style.font.family
                        font.pixelSize: Style.font.caption
                        wrapMode: Text.WordWrap
                    }
                }
            }
        }
    }
}
