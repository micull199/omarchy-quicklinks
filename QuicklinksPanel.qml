import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar icon plus a search-first popup. The list view opens a quicklink; the
// builder view creates or edits one (name, URL, private-window toggle).
// Reading and writing entries is delegated to bin/quicklinks inside this
// plugin folder, so the storage rules live in one place and are testable on
// their own.
Panel {
  id: root
  moduleName: "micull199.quicklinks"
  ipcTarget: "micull199.quicklinks"
  // manageIpc: false so this panel can own the single IpcHandler the target
  // permits, and add newLink() for the menu's "Install > Quicklink" row.
  manageIpc: false

  readonly property string backend: String(Qt.resolvedUrl("bin/quicklinks")).replace(/^file:\/\//, "")

  property var links: []            // [{ name, url, icon, private }]
  property string filterText: ""
  property int selectedIndex: 0     // cursor in the link list
  property bool building: false
  property bool privateWindow: false // builder: pass --private to save
  property string editingName: ""   // "" while creating a new link
  property string errorText: ""
  property bool confirmOpen: false
  property string confirmName: ""   // link awaiting delete confirmation

  readonly property color fg: bar ? bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(fg, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property int rowHeight: Math.max(Style.space(28), Style.font.body + Style.spacing.sm * 2)
  readonly property int iconSize: Style.font.icon
  readonly property string fallbackIcon: {
    var browser = Quickshell.iconPath("web-browser", true)
    return browser.length > 0 ? browser : Quickshell.iconPath("application-x-executable", true)
  }

  readonly property var filteredLinks: {
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

  // ------------------------------------------------------------ lookups

  // Icon for a link, from the Icon= value the backend reports. Mirrors the
  // shell's AppLibrary.iconSource fallbacks (absolute paths, themed lookup,
  // generic browser icon) without its icon-directory index.
  function iconSource(icon) {
    var value = String(icon || "")
    if (value.length === 0) return root.fallbackIcon
    if (value.indexOf("file://") === 0 || value.indexOf("image://") === 0) return value
    if (value.charAt(0) === "/") return "file://" + value
    var themed = Quickshell.iconPath(value, true)
    return themed.length > 0 ? themed : root.fallbackIcon
  }

  // ------------------------------------------------------------ backend parsing

  function reload() {
    if (!listProc.running) listProc.running = true
  }

  function stderrOf(proc, fallback) {
    var message = ""
    try { message = String(proc.stderr.text || "").trim() } catch (e) { message = "" }
    return message !== "" ? message : fallback
  }

  function applyLinks(raw) {
    var out = []
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      if (lines[i].trim() === "") continue
      var parts = lines[i].split("\t")
      if (parts.length < 2) continue
      out.push({
        name: parts[0],
        url: parts[1],
        icon: parts.length > 2 ? parts[2] : "",
        private: parts.length > 3 && parts[3].trim() === "true"
      })
    }
    root.links = out
    if (root.selectedIndex >= root.filteredLinks.length)
      root.selectedIndex = Math.max(0, root.filteredLinks.length - 1)
  }

  function applyInfo(raw) {
    var lines = String(raw || "").split("\n")
    for (var i = 0; i < lines.length; i++) {
      var parts = lines[i].split("\t")
      if (parts.length < 2) continue
      var key = parts[0].trim()
      var value = parts.slice(1).join("\t").trim()
      if (key === "url" && value !== "") urlField.text = value
      else if (key === "private") root.privateWindow = value === "true"
    }
  }

  // ------------------------------------------------------------ list actions

  function openLink(link) {
    if (!link) return
    Quickshell.execDetached([root.backend, "open", link.name])
    root.close()
  }

  function openSelected() {
    root.openLink(root.filteredLinks[root.selectedIndex])
  }

  function copySelected() {
    var link = root.filteredLinks[root.selectedIndex]
    if (!link) return
    Quickshell.execDetached(["wl-copy", link.url])
    root.close()
  }

  function move(delta) {
    if (root.filteredLinks.length === 0) return
    linkGate.reset()
    root.selectedIndex = (root.selectedIndex + delta + root.filteredLinks.length) % root.filteredLinks.length
    list.positionViewAtIndex(root.selectedIndex, ListView.Contain)
  }

  function requestRemoveSelected() {
    var link = root.filteredLinks[root.selectedIndex]
    if (!link) return
    root.errorText = ""
    root.confirmName = link.name
    deleteConfirm.selectedIndex = 1
    root.confirmOpen = true
    Qt.callLater(function() { confirmKeys.forceActiveFocus() })
  }

  function cancelRemove() {
    root.confirmOpen = false
    root.confirmName = ""
    Qt.callLater(function() { search.forceActiveFocus() })
  }

  function confirmRemove() {
    var name = root.confirmName
    root.confirmOpen = false
    root.confirmName = ""
    if (name !== "") {
      actionProc.command = [root.backend, "remove", name]
      actionProc.running = true
    }
    Qt.callLater(function() { search.forceActiveFocus() })
  }

  // ------------------------------------------------------------ builder

  function startNew() {
    root.editingName = ""
    root.privateWindow = false
    root.errorText = ""
    root.building = true
    Qt.callLater(function() {
      nameField.text = ""
      urlField.text = ""
      nameField.forceActiveFocus()
    })
  }

  function startEdit() {
    var link = root.filteredLinks[root.selectedIndex]
    if (!link) return
    root.editingName = link.name
    root.privateWindow = link.private === true
    root.errorText = ""
    root.building = true
    // The row already carries url/private; `info` refreshes them from disk in
    // case the list is stale or came from an older 3-column backend.
    infoProc.command = [root.backend, "info", link.name]
    infoProc.running = true
    Qt.callLater(function() {
      nameField.text = link.name
      urlField.text = link.url
      nameField.forceActiveFocus()
    })
  }

  function cancelBuild() {
    root.building = false
    root.errorText = ""
    Qt.callLater(function() { search.forceActiveFocus() })
  }

  // Only reached once the backend has exited 0. Until then the builder stays
  // open with the user's input intact so a failure can be retried.
  function finishBuild() {
    root.building = false
    root.errorText = ""
    root.reload()
    Qt.callLater(function() { search.forceActiveFocus() })
  }

  function save() {
    if (saveProc.running) return
    var name = nameField.text.trim()
    var url = urlField.text.trim()
    if (name === "") { root.errorText = "The quicklink needs a name"; return }
    if (url === "") { root.errorText = "The quicklink needs a URL"; return }
    root.errorText = ""

    // Editing is a single `edit` call carrying every field; the backend
    // treats unchanged values as no-ops, so a rename and a URL change are
    // one atomic step.
    if (root.editingName !== "") {
      saveProc.command = [root.backend, "edit", root.editingName, "--name", name, "--url", url,
                          root.privateWindow ? "--private" : "--no-private"]
    } else {
      var args = [root.backend, "add", name, url]
      if (root.privateWindow) args.push("--private")
      saveProc.command = args
    }
    saveProc.running = true
  }

  onOpenedChanged: {
    if (opened) {
      root.filterText = ""
      root.selectedIndex = 0
      root.building = false
      root.confirmOpen = false
      root.confirmName = ""
      root.errorText = ""
      linkGate.reset()
      root.reload()
    }
  }

  IpcHandler {
    target: "micull199.quicklinks"

    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    // Opens the panel straight into the builder.
    function newLink(): void {
      root.open()
      Qt.callLater(function() { root.startNew() })
    }
  }

  // Filters hover churn: a delegate sliding under a resting pointer must not
  // steal the cursor from the keyboard.
  PointerMoveGate { id: linkGate; referenceItem: column }

  // ------------------------------------------------------------ processes

  Process {
    id: listProc
    command: [root.backend, "list"]
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyLinks(text) }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(code, status) {
      if (code !== 0) root.errorText = root.stderrOf(listProc, "quicklinks list failed (exit " + code + ")")
    }
  }

  // Adds the Omarchy menu rows (Quicklinks, Install > Quicklink,
  // Remove > Quicklink). The menu has no plugin API, so this is the only way
  // they can appear automatically. menu-install does nothing when the rows
  // are already correct. `quicklinks menu-uninstall` removes them again.
  Process {
    id: menuInstallProc
    command: [root.backend, "menu-install"]
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(code, status) {
      var message = root.stderrOf(menuInstallProc, "")
      if (code !== 0 && message === "") message = "quicklinks menu-install failed (exit " + code + ")"
      if (message !== "") root.errorText = message
    }
  }

  Component.onCompleted: menuInstallProc.running = true

  Process {
    id: infoProc
    stdout: StdioCollector { waitForEnd: true; onStreamFinished: root.applyInfo(text) }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(code, status) {
      if (code !== 0) root.errorText = root.stderrOf(infoProc, "quicklinks info failed (exit " + code + ")")
    }
  }

  Process {
    id: actionProc
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(code, status) {
      if (code !== 0) root.errorText = root.stderrOf(actionProc, "quicklinks command failed (exit " + code + ")")
      root.reload()
    }
  }

  Process {
    id: saveProc
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(code, status) {
      if (code !== 0) {
        root.errorText = root.stderrOf(saveProc, "quicklinks save failed (exit " + code + ")")
        return
      }
      root.finishBuild()
    }
  }

  // ------------------------------------------------------------ ui

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰌷"
    tooltipText: ""
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: root.building ? nameField : search
    contentWidth: panel.fittedContentWidth(Style.space(440))
    contentHeight: panel.fittedContentHeight(Math.max(column.implicitHeight, root.confirmOpen ? Style.space(150) : 0))

    // Delete confirmation. Sits above the content and owns the keyboard while
    // open; ConfirmDialog has no key handling of its own, so confirmKeys feeds
    // it through handleKey() the way the clipboard picker does.
    Item {
      id: confirmKeys
      anchors.fill: parent
      z: 10
      visible: root.confirmOpen
      Keys.onPressed: function(event) {
        if (!root.confirmOpen) return
        deleteConfirm.handleKey(event)
        event.accepted = true
      }

      ConfirmDialog {
        id: deleteConfirm
        anchors.fill: parent
        opened: root.confirmOpen
        message: "Delete quicklink \"" + root.confirmName + "\"?"
        confirmText: "Delete"
        background: Color.popups.background
        foreground: root.fg
        fontFamily: root.fontFamily
        onCanceled: root.cancelRemove()
        onConfirmed: root.confirmRemove()
      }
    }

    Column {
      id: column
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      spacing: Style.space(8)

      // ============================================================ list view
      TextField {
        id: search
        width: parent.width
        visible: !root.building
        foreground: root.fg
        placeholderText: "Search quicklinks"
        text: root.filterText
        onTextChanged: {
          if (text !== root.filterText) { root.filterText = text; root.selectedIndex = 0; linkGate.reset() }
        }
        Keys.onPressed: function(event) {
          if (root.confirmOpen) { event.accepted = true; return }
          var ctrl = event.modifiers & Qt.ControlModifier
          if (event.key === Qt.Key_Down) { root.move(1); event.accepted = true }
          else if (event.key === Qt.Key_Up) { root.move(-1); event.accepted = true }
          else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.openSelected(); event.accepted = true }
          else if (event.key === Qt.Key_Escape) { root.close(); event.accepted = true }
          else if (event.key === Qt.Key_Delete) { root.requestRemoveSelected(); event.accepted = true }
          else if (ctrl && event.key === Qt.Key_N) { root.startNew(); event.accepted = true }
          else if (ctrl && event.key === Qt.Key_E) { root.startEdit(); event.accepted = true }
          else if (ctrl && event.key === Qt.Key_C) { root.copySelected(); event.accepted = true }
        }
      }

      ListView {
        id: list
        width: parent.width
        height: Math.min(root.filteredLinks.length * root.rowHeight, Style.space(300))
        visible: !root.building && root.filteredLinks.length > 0
        clip: true
        model: root.filteredLinks
        currentIndex: root.selectedIndex

        delegate: Rectangle {
          id: linkRow
          width: list.width
          height: root.rowHeight
          radius: Style.cornerRadius
          color: index === root.selectedIndex ? Style.selectedFillFor(root.fg, Color.accent) : "transparent"

          readonly property bool isPrivate: modelData.private === true

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.spacing.sm
            anchors.rightMargin: Style.spacing.sm
            spacing: Style.spacing.sm

            Image {
              anchors.verticalCenter: parent.verticalCenter
              width: root.iconSize
              height: root.iconSize
              fillMode: Image.PreserveAspectFit
              sourceSize.width: width * Screen.devicePixelRatio
              sourceSize.height: height * Screen.devicePixelRatio
              source: root.iconSource(modelData.icon)
              asynchronous: true
            }

            Text {
              width: Math.round(list.width * 0.4)
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.name
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
            }

            Text {
              width: parent.width - Math.round(list.width * 0.4) - root.iconSize - parent.spacing * 2
                     - (linkRow.isPrivate ? root.iconSize + parent.spacing : 0)
              anchors.verticalCenter: parent.verticalCenter
              text: modelData.url
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              elide: Text.ElideRight
            }

            // Lock glyph for links that open in a private window.
            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: root.iconSize
              visible: linkRow.isPrivate
              text: "󰒃"
              color: index === root.selectedIndex ? Color.accent : root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              horizontalAlignment: Text.AlignHCenter
            }
          }

          MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onPositionChanged: function(mouse) {
              if (linkGate.moved(linkRow, mouse)) root.selectedIndex = index
            }
            onClicked: { root.selectedIndex = index; root.openLink(modelData) }
          }
        }
      }

      Text {
        width: parent.width
        visible: !root.building && root.filteredLinks.length === 0
        text: root.links.length === 0
          ? "No quicklinks yet. Press + to build one."
          : "Nothing matches \"" + root.filterText + "\""
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      // ========================================================= builder view
      // One key dispatcher for the whole builder. BeforeItem so the shortcuts
      // win over the focused TextField, while plain typing still falls
      // through to whichever field has focus.
      Item {
        id: builderKeys
        width: parent.width
        height: builderColumn.implicitHeight
        visible: root.building

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (!root.building) return
          var ctrl = event.modifiers & Qt.ControlModifier
          var enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter
          if (event.key === Qt.Key_Escape) { root.cancelBuild(); event.accepted = true }
          else if (enter && ctrl) { root.save(); event.accepted = true }
          else if (ctrl && event.key === Qt.Key_P) { root.privateWindow = !root.privateWindow; event.accepted = true }
          else if (enter && nameField.activeFocus) { urlField.forceActiveFocus(); event.accepted = true }
          else if (enter) { root.save(); event.accepted = true }
        }

        Column {
          id: builderColumn
          width: parent.width
          spacing: Style.space(8)

          TextField {
            id: nameField
            width: parent.width
            foreground: root.fg
            placeholderText: "Quicklink name, e.g. Invoices"
          }

          TextField {
            id: urlField
            width: parent.width
            foreground: root.fg
            placeholderText: "https://example.com"
          }

          // Private-window toggle, kept to a single compact row.
          Item {
            width: parent.width
            height: privateSwitch.implicitHeight

            Text {
              anchors.left: parent.left
              anchors.right: privateSwitch.left
              anchors.rightMargin: Style.spacing.sm
              anchors.verticalCenter: parent.verticalCenter
              text: "Open in a private window"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.privateWindow = !root.privateWindow
              }
            }

            ToggleSwitch {
              id: privateSwitch
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              checked: root.privateWindow
              foreground: root.fg
              onToggled: root.privateWindow = !root.privateWindow
            }
          }

          Text {
            width: parent.width
            text: (root.editingName !== "" ? "Editing \"" + root.editingName + "\" · " : "")
                  + "Enter moves on · Ctrl+Enter saves · Ctrl+P toggles private · Esc cancels"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            wrapMode: Text.WordWrap
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

      // =============================================================== footer
      Row {
        width: parent.width
        spacing: Style.spacing.sm

        PanelActionButton {
          visible: !root.building
          iconText: "󰉉"
          tooltipText: "New quicklink (Ctrl+N)"
          foreground: root.fg
          fontFamily: root.fontFamily
          onClicked: root.startNew()
        }

        PanelActionButton {
          visible: !root.building && root.filteredLinks.length > 0
          iconText: "󰏫"
          tooltipText: "Edit the selected quicklink (Ctrl+E)"
          foreground: root.fg
          fontFamily: root.fontFamily
          onClicked: root.startEdit()
        }

        PanelActionButton {
          visible: !root.building && root.filteredLinks.length > 0
          iconText: "󰭌"
          tooltipText: "Delete the selected quicklink (Del)"
          foreground: root.fg
          hoverColor: Color.urgent
          fontFamily: root.fontFamily
          onClicked: root.requestRemoveSelected()
        }

        PanelActionButton {
          visible: root.building
          iconText: "󰄬"
          tooltipText: "Save (Ctrl+Enter)"
          enabled: !saveProc.running
          foreground: root.fg
          fontFamily: root.fontFamily
          onClicked: root.save()
        }

        PanelActionButton {
          visible: root.building
          iconText: "󰅙"
          tooltipText: "Cancel (Esc)"
          foreground: root.fg
          fontFamily: root.fontFamily
          onClicked: root.cancelBuild()
        }
      }
    }
  }
}
