import QtQuick
import QtCore

import org.qfield
import org.qgis
import Theme

import "qrc:/qml" as QFieldItems

Item {
    id: plugin

    property var mainWindow: iface.mainWindow()
    property var featureForm: iface.findItemByObjectName("featureForm")
    property var projectInfo: iface.findItemByObjectName("projectInfo")

    property var navigationBar
    property var selection: featureForm.selection
    property var model: featureForm.model

    property string icon: "icon.svg"
    property string icon_filled: "icon_filled.svg"

    property var selectedFeature
    property var votesLayer
    property var voteFeature

    // keep a reference to the created button for bindings
    property var voteButtonRef

    Component.onCompleted: {
        // get the NavigationBar instance
        for (let i = 0; i < featureForm.children.length; ++i) {
            const child = featureForm.children[i];
            if (child && child.toString && String(child).indexOf("NavigationBar") !== -1) {
                navigationBar = child;
                break;
            }
        }
        voteButtonRef = voteButtonComponent.createObject(navigationBar, { "plugin": plugin });

        // create the button
        /*voteButtonRef = comp.createObject(navigationBar, {
            "plugin": plugin
        });
        /*
        // add our width to the right margin so the title centers correctly
        // re-create the original binding (mainWindow.sceneRightMargin) + our extra
        Qt.createQmlObject(`
            import QtQuick
            Binding {
                target: plugin.navigationBar
                property: "rightMargin"
                value: plugin.mainWindow.sceneRightMargin
                       + ((plugin.voteButtonRef && plugin.voteButtonRef.visible) ? (plugin.voteButtonRef.width + plugin.voteButtonRef.gap) : 0)
            }
        `, plugin, "RightMarginBinding")*/
    }

    // restore the original binding on unload
    Component.onDestruction: {
        if (navigationBar) {
            navigationBar.rightMargin = Qt.binding(function () {
                return plugin.mainWindow.sceneRightMargin;
            });
        }
        voteButtonRef?.destroy();
    }
    Component {
        id: voteButtonComponent
        QfToolButton {
            id: voteButton
            property var plugin: null
            parent: plugin.navigationBar

            // UI
            iconSource: plugin && plugin.voteFeature ? plugin.icon_filled : plugin && plugin.icon
            iconColor: Theme.mainOverlayColor
            round: true
            enabled: true
            visible: ((plugin && plugin.selection && plugin.selection.focusedItem > -1 && plugin.selection.focusedLayer) && (plugin.selectedFeature?.attribute("creationuser") != plugin.projectInfo.cloudUserInformation.username))
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
                const bar = plugin ? plugin.navigationBar : null;
                if (!bar)
                    return 0;

                const buttons = [];
                const children = bar.children || [];
                for (let i = 0; i < children.length; ++i) {
                    const it = children[i];
                    if (!it || it === voteButton)
                        continue;
                    // Heuristic: treat QfToolButton-like siblings only
                    if (typeof it.iconSource !== 'undefined' && it.visible && it.width > 0 && it.height > 0) {
                        // Same row as toolbar buttons
                        const top = Number(bar.topMargin) || 0;
                        if (Math.abs((Number(it.y) || 0) - top) < 1.0) {
                            buttons.push(it);
                        }
                    }
                }

                // If none found, fall back to hugging the bar's right margin
                if (!buttons.length) {
                    const rm = (typeof bar.rightMargin === 'number') ? bar.rightMargin : 0;
                    return Math.max(0, bar.width - rm - voteButton.width);
                }

                // Find the rightmost button (by visual right edge)
                let rightmost = buttons[0];
                let maxRight = (rightmost.x || 0) + (rightmost.width || 0);
                for (let i = 1; i < buttons.length; ++i) {
                    const r = (buttons[i].x || 0) + (buttons[i].width || 0);
                    if (r > maxRight) {
                        maxRight = r;
                        rightmost = buttons[i];
                    }
                }

                // Walk left across any buttons that abut the current left edge
                let left = Number(rightmost.x) || 0;
                const eps = 0.75;
                let changed = true;
                while (changed) {
                    changed = false;
                    for (let i = 0; i < buttons.length; ++i) {
                        const it = buttons[i];
                        const itRight = (Number(it.x) || 0) + (Number(it.width) || 0);
                        if (Math.abs(itRight - left) < eps) {
                            const newLeft = Number(it.x) || 0;
                            if (newLeft < left) {
                                left = newLeft;
                                changed = true;
                            }
                        }
                    }
                }

                // Place our button immediately to the left of the cluster
                return Math.max(0, left - voteButton.width - voteButton.gap);
            }

            onClicked: {
                findVotesLayer();

                if (hasUserVotedForFeature()) {
                    plugin.votesLayer.startEditing();
                    plugin.votesLayer.deleteFeature(plugin.voteFeature.id);
                    plugin.votesLayer.commitChanges();
                    hasUserVotedForFeature();
                    return;
                }

                const f = FeatureUtils.createFeature(plugin.votesLayer);
                const userIdx = f.fields.names.indexOf("user");
                const featureIdx = f.fields.names.indexOf("feature");
                if (userIdx < 0 || featureIdx < 0) {
                    iface.logMessage("[createVoteForCurrentFeature] Could not find 'user' or 'feature' fields");
                    return false;
                }
                //iface.logMessage(String(plugin.selectedFeature.attribute("id")))
                f.setAttribute(userIdx, String(plugin.projectInfo.cloudUserInformation.username));
                f.setAttribute(featureIdx, String(plugin.selectedFeature.attribute("id")));
                plugin.votesLayer.startEditing();
                LayerUtils.addFeature(plugin.votesLayer, f);
                plugin.votesLayer.commitChanges();
                hasUserVotedForFeature();
            }

            function hasUserVotedForFeature() {
                plugin.voteFeature = null;
                if (!plugin.votesLayer || !plugin.selection.focusedFeature)
                    return false;

                const userExpr = "\"user\" = " + quoteLiteral(plugin.projectInfo.cloudUserInformation.username);
                const featureExpr = "\"feature\" = " + quoteLiteral(plugin.selectedFeature.attribute("id"));
                const expr = userExpr + " AND " + featureExpr;

                const it = LayerUtils.createFeatureIteratorFromExpression(plugin.votesLayer, expr);
                let found = false;
                while (it.hasNext()) {
                    const f = it.next();
                    plugin.voteFeature = f;
                    found = true;
                    break;
                }
                it.close();
                return found;
            }

            function quoteLiteral(s) {
                return "'" + String(s).replace(/'/g, "''") + "'";
            }

            function findVotesLayer() {
                let map = ProjectUtils.mapLayers(qgisProject);
                for (let id in map) {
                    let layer = map[id];
                    if (layer && layer.name === "votes") {
                        plugin.votesLayer = layer;
                        return;
                    }
                }
            }

            Connections {
                target: plugin ? plugin.selection : null
                function onFocusedItemChanged() {
                    voteButton.findVotesLayer();
                    plugin.selectedFeature = null;
                    if (!plugin.selection.focusedFeature || plugin.selection.focusedFeature.id < 0)
                        return;
                    plugin.selectedFeature = plugin.selection.focusedFeature;
                    voteButton.hasUserVotedForFeature();
                }
            }

            /*Connections {
            target: plugin
            function onDestroyed() {
                voteButton.destroy();
            }
        }*/
        }
    }
}
