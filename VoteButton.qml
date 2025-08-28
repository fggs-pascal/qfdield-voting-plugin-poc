import QtQuick
import QtCore

import org.qfield
import org.qgis
import Theme

QfToolButton {
    id: voteButton
    property var plugin: null

    // UI
    iconSource: plugin && plugin.voteFeature ? plugin.icon_filled : plugin && plugin.icon
    iconColor: Theme.mainOverlayColor
    round: true
    enabled: true
    visible: (plugin && plugin.selection && plugin.selection.focusedItem > -1 && plugin.selection.focusedLayer)
    width: 48
    height: 48
    clip: true
    z: 10

    // Layout
    anchors.top: parent.top
    anchors.topMargin: plugin && plugin.navigationBar ? plugin.navigationBar.topMargin : 0

    // Place just to the left of the right-side button cluster
    property int gap: 0
    x: {
        const bar = plugin ? plugin.navigationBar : null
        if (!bar) return 0

        const buttons = []
        const children = bar.children || []
        for (let i = 0; i < children.length; ++i) {
            const it = children[i]
            if (!it || it === voteButton) continue
            // Heuristic: treat QfToolButton-like siblings only
            if (typeof it.iconSource !== 'undefined' && it.visible && it.width > 0 && it.height > 0) {
                // Same row as toolbar buttons
                const top = Number(bar.topMargin) || 0
                if (Math.abs((Number(it.y) || 0) - top) < 1.0) {
                    buttons.push(it)
                }
            }
        }

        // If none found, fall back to hugging the bar's right margin
        if (!buttons.length) {
            const rm = (typeof bar.rightMargin === 'number') ? bar.rightMargin : 0
            return Math.max(0, bar.width - rm - voteButton.width)
        }

        // Find the rightmost button (by visual right edge)
        let rightmost = buttons[0]
        let maxRight = (rightmost.x || 0) + (rightmost.width || 0)
        for (let i = 1; i < buttons.length; ++i) {
            const r = (buttons[i].x || 0) + (buttons[i].width || 0)
            if (r > maxRight) {
                maxRight = r
                rightmost = buttons[i]
            }
        }

        // Walk left across any buttons that abut the current left edge
        let left = Number(rightmost.x) || 0
        const eps = 0.75
        let changed = true
        while (changed) {
            changed = false
            for (let i = 0; i < buttons.length; ++i) {
                const it = buttons[i]
                const itRight = (Number(it.x) || 0) + (Number(it.width) || 0)
                if (Math.abs(itRight - left) < eps) {
                    const newLeft = Number(it.x) || 0
                    if (newLeft < left) {
                        left = newLeft
                        changed = true
                    }
                }
            }
        }

        // Place our button immediately to the left of the cluster
        return Math.max(0, left - voteButton.width - voteButton.gap)
    }

    onClicked: {
        findVotesLayer()

        if (hasUserVotedForFeature()) {
            plugin.votesLayer.startEditing()
            plugin.votesLayer.deleteFeature(plugin.voteFeature.id)
            plugin.votesLayer.commitChanges()
            hasUserVotedForFeature()
            return
        }

        const f = FeatureUtils.createFeature(plugin.votesLayer)
        const userIdx = f.fields.names.indexOf("user")
        const featureIdx = f.fields.names.indexOf("feature")
        if (userIdx < 0 || featureIdx < 0) {
            iface.logMessage("[createVoteForCurrentFeature] Could not find 'user' or 'feature' fields")
            return false
        }

        f.setAttribute(userIdx, String(plugin.projectInfo.cloudUserInformation.username))
        f.setAttribute(featureIdx, String(plugin.selectedFeature.id))
        plugin.votesLayer.startEditing()
        LayerUtils.addFeature(plugin.votesLayer, f)
        plugin.votesLayer.commitChanges()
        hasUserVotedForFeature()
    }

    function hasUserVotedForFeature() {
        plugin.voteFeature = null
        if (!plugin.votesLayer || !plugin.selection.focusedFeature) return false

        const userExpr = "\"user\" = " + quoteLiteral(plugin.projectInfo.cloudUserInformation.username)
        const featureExpr = "\"feature\" = " + quoteLiteral(plugin.selectedFeature.id)
        const expr = userExpr + " AND " + featureExpr

        const it = LayerUtils.createFeatureIteratorFromExpression(plugin.votesLayer, expr)
        let found = false
        while (it.hasNext()) {
            const f = it.next()
            plugin.voteFeature = f
            found = true
            break
        }
        it.close()
        return found
    }

    function quoteLiteral(s) {
        return "'" + String(s).replace(/'/g, "''") + "'"
    }

    function findVotesLayer() {
        let map = ProjectUtils.mapLayers(qgisProject)
        for (let id in map) {
            let layer = map[id]
            if (layer && layer.name === "votes") {
                plugin.votesLayer = layer
                return
            }
        }
    }

    Connections {
        target: plugin ? plugin.selection : null
        function onFocusedItemChanged() {
            voteButton.findVotesLayer();
            voteButton.plugin.selectedFeature = null;
            if (!voteButton.plugin.selection.focusedFeature || voteButton.plugin.selection.focusedFeature.id < 0) return
            voteButton.plugin.selectedFeature = voteButton.plugin.selection.focusedFeature
            voteButton.hasUserVotedForFeature();

            iface.logMessage("test :D")
            iface.logMessage(voteButton.plugin.selectedFeature.attribute("creationuser"))
        }
    }

    Connections {
        target: plugin
        function onDestroyed() {
            voteButton.destroy();
        }
    }
}