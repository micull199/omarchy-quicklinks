import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar icon plus a search-first popup listing every quicklink. Reading and
// writing the entries is delegated to bin/quicklinks inside this plugin
// folder, so the storage rules live in one place and are testable on their own.
Panel {
  id: root
  moduleName: "micull199.quicklinks"
  ipcTarget: "micull199.quicklinks"

  // Resolved from this file's own location, so the plugin works wherever it is
  // installed without needing anything on PATH.
  readonly property string backend: String(Qt.resolvedUrl("bin/quicklinks")).replace(/^file:\/\//, "")

  property var links: []
  property string filterText: ""
  property int selectedIndex: 0
  property bool adding: false
  property string errorText: ""

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(fg, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property int rowHeight: Math.max(Style.space(28), Style.font.body + Style.spacing.sm * 2)

  readonly property var filtered: {
    var query = root.filterText.trim().toLowerCase()
    if (query === "") return root.links
    var out = []
    for (var i = 0; i < root.links.length; i++) {
      var link = root.links[i]
      if (link.name.toLowerCase().indexOf(query) !== -1 || link.url.toLowerCase().indexOf(query) !== -1)
        out.push(link)
    }
    return out
  }

  function clampSelection() {
    if (root.selectedIndex >= root.filtered.length) root.selectedIndex = Math.max(0, root.filtered.length - 1)
    if (root.selectedIndex < 0) root.selectedIndex = 0
  }

  function reload() {
    if (listProc.running) return
    listProc.running = true
  }

  function applyList(raw) {
    var out = []
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var line = lines[i]
      if (line.trim() === "") continue
      var parts = line.split("\t")
      if (parts.length < 2) continue
      out.push({ name: parts[0], url: parts[1], icon: parts.length > 2 ? parts[2] : "" })
    }
    root.links = out
    root.clampSelection()
  }

  function openLink(link) {
    if (!link) return
    Quickshell.execDetached(["omarchy-launch-browser", link.url])
    root.close()
  }

  function openSelected() {
    root.openLink(root.filtered[root.selectedIndex])
  }

  function runAction(args) {
    if (actionProc.running) return
    root.errorText = ""
    actionProc.command = [root.backend].concat(args)
    actionProc.running = true
  }

  function removeSelected() {
    var link = root.filtered[root.selectedIndex]
    if (!link) return
    root.runAction(["remove", link.name])
  }

  function submitNew() {
    var name = nameField.text.trim()
    var url = urlField.text.trim()
    if (name === "" || url === "") {
      root.errorText = "A name and a URL are both required"
      return
    }
    root.runAction(["add", name, url])
    nameField.text = ""
    urlField.text = ""
    root.adding = false
  }

  function move(delta) {
    if (root.filtered.length === 0) return
    root.selectedIndex = (root.selectedIndex + delta + root.filtered.length) % root.filtered.length
  }

  onOpenedChanged: {
    if (opened) {
      root.filterText = ""
      root.selectedIndex = 0
      root.adding = false
      root.errorText = ""
      root.reload()
    }
  }

  Process {
    id: listProc
    command: [root.backend, "list"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyList(text)
    }
  }

  Process {
    id: actionProc
    stderr: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        var message = String(text || "").trim()
        if (message !== "") root.errorText = message
      }
    }
    onExited: root.reload()
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: ""
    tooltipText: ""
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: search
    contentWidth: panel.fittedContentWidth(Style.space(420))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    Column {
      id: column
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(8)

      TextField {
        id: search
        width: parent.width
        foreground: root.fg
        placeholderText: root.adding ? "Adding a quicklink…" : "Search quicklinks"
        enabled: !root.adding
        text: root.filterText
        onTextChanged: {
          if (text !== root.filterText) {
            root.filterText = text
            root.selectedIndex = 0
          }
        }

        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Down) { root.move(1); event.accepted = true }
          else if (event.key === Qt.Key_Up) { root.move(-1); event.accepted = true }
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.openSelected(); event.accepted = true }
          else if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
          else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) { root.removeSelected(); event.accepted = true }
        }
      }

      // ---------------------------------------------------------- the list
      ListView {
        id: list
        width: parent.width
        height: Math.min(root.filtered.length * root.rowHeight, Style.space(300))
        visible: !root.adding && root.filtered.length > 0
        clip: true
        interactive: true
        model: root.filtered
        currentIndex: root.selectedIndex

        delegate: Rectangle {
          width: list.width
          height: root.rowHeight
          radius: Style.cornerRadius
          color: index === root.selectedIndex
            ? Style.selectedFillFor(root.fg, Color.accent)
            : (rowMouse.containsMouse ? Style.hoverFillFor(root.fg, Color.accent) : "transparent")

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.spacing.sm
            anchors.rightMargin: Style.spacing.sm
            spacing: Style.spacing.sm

            Text {
              width: Math.round(list.width * 0.42)
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.name
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }

            Text {
              width: parent.width - Math.round(list.width * 0.42) - Style.spacing.sm
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.url
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }
          }

          MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton
            onEntered: root.selectedIndex = index
            onClicked: root.openLink(modelData)
          }
        }
      }

      // --------------------------------------------------------- empty state
      Text {
        width: parent.width
        visible: !root.adding && root.filtered.length === 0
        text: root.links.length === 0
          ? "No quicklinks yet. Press the + below to add one."
          : "Nothing matches \"" + root.filterText + "\""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      // ------------------------------------------------------------ add form
      Column {
        width: parent.width
        visible: root.adding
        spacing: Style.space(6)

        TextField {
          id: nameField
          width: parent.width
          foreground: root.fg
          placeholderText: "Name, e.g. Invoices"
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.adding = false; event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { urlField.forceActiveFocus(); event.accepted = true }
          }
        }

        TextField {
          id: urlField
          width: parent.width
          foreground: root.fg
          placeholderText: "https://example.com"
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) { root.adding = false; event.accepted = true }
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.submitNew(); event.accepted = true }
          }
        }
      }

      Text {
        width: parent.width
        visible: root.errorText !== ""
        text: root.errorText
        color: Color.urgent
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      // -------------------------------------------------------------- footer
      Row {
        width: parent.width
        spacing: Style.spacing.sm

        PanelActionButton {
          iconText: root.adding ? "" : "󰉉"
          tooltipText: root.adding ? "Cancel" : "Add a quicklink"
          foreground: root.fg
          fontFamily: root.fontFamily
          onClicked: {
            root.adding = !root.adding
            root.errorText = ""
            if (root.adding) Qt.callLater(function() { nameField.forceActiveFocus() })
            else Qt.callLater(function() { search.forceActiveFocus() })
          }
        }

        PanelActionButton {
          visible: root.adding
          iconText: "󰀻"
          tooltipText: "Save"
          foreground: root.fg
          fontFamily: root.fontFamily
          onClicked: root.submitNew()
        }

        PanelActionButton {
          visible: !root.adding && root.filtered.length > 0
          iconText: "󰭌"
          tooltipText: "Delete the selected quicklink"
          foreground: root.fg
          fontFamily: root.fontFamily
          onClicked: root.removeSelected()
        }
      }
    }
  }
}
