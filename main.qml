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
            const child = featureForm.children[i]
            if (child && child.toString && String(child).indexOf("NavigationBar") !== -1) {
                navigationBar = child
                break
            }
        }

        // create the button
        const comp = Qt.createComponent("VoteButton.qml")
        voteButtonRef = comp.createObject(navigationBar, { "plugin": plugin })
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
            navigationBar.rightMargin = Qt.binding(function() { return plugin.mainWindow.sceneRightMargin })
        }
    }
}
