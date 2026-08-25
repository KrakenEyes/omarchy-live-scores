import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar pill for the live-scores plugin. Follows the first-party pattern:
// the widget owns the button and lazily loads the panel, forwarding the
// open/close contract the bar's popout coordinator expects. All state
// comes from the plugin's service, so two monitors show the same thing
// without either of them polling.
BarWidget {
  id: root
  moduleName: "krakeneyes.live-scores"

  readonly property var scores: bar && bar.shell ? bar.shell.serviceFor("krakeneyes.live-scores") : null

  readonly property var liveMatches: scores ? scores.allLiveFollowedMatches : []
  readonly property var currentMatch: liveMatches.length > 0 ? liveMatches[0] : null

  readonly property color defaultForeground: bar ? bar.barForeground : Color.foreground
  readonly property string glyph: currentMatch ? Model.glyphForSlug(currentMatch.leagueSlug) : Model.GLYPH_TROPHY

  readonly property bool showLabel: setting("compactBarLabel", true) === true
  readonly property string label: currentMatch && showLabel ? Model.eventLabel(currentMatch) : ""

  // The shell injects `settings` into widgets but not into services, so the
  // widget forwards them — every bar instance writes the same value, which
  // is harmless since they all read the same shell.json entry.
  function syncService() {
    if (root.scores && "settings" in root.scores) root.scores.settings = root.settings
  }

  // Persist a single settings key while preserving the rest, following the
  // `updateEntryInline` pattern documented for bar widgets.
  function saveSetting(name, value) {
    var next = {}
    for (var k in root.settings) next[k] = root.settings[k]
    next[name] = value
    root.settings = next
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(root.moduleName, next)
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
    if ("scores" in target) target.scores = root.scores
  }

  function togglePanel() {
    if (panelLoader.item && panelLoader.item.toggle) panelLoader.item.toggle()
  }

  // Shape contract for shell summon/hide/toggle routing: the bar identifies
  // a panel by the widget mounted in its slot, so open/close/opened have to
  // live on this root rather than on the nested panel.
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item && panelLoader.item.openFromHotkey) panelLoader.item.openFromHotkey()
  }

  function close() {
    if (panelLoader.item && panelLoader.item.close) panelLoader.item.close()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: { injectPanel(); syncService() }
  onScoresChanged: { injectPanel(); syncService() }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.label !== "" ? root.glyph + "  " + root.label : root.glyph
    foreground: root.currentMatch ? Color.urgent : root.defaultForeground
    slotSize: Style.bar.statusSlot
    tooltipText: ""

    onPressed: function(b) {
      if (b === Qt.MiddleButton && root.scores) root.scores.refreshScoreboards()
      else root.togglePanel()
    }
  }
}
