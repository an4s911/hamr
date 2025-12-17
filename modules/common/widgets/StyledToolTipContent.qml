import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    required property string text
    property string keys: ""
    property bool shown: false
    property real horizontalPadding: 10
    property real verticalPadding: 5
    property alias font: tooltipTextObject.font
    implicitWidth: tooltipContent.implicitWidth + 2 * root.horizontalPadding
    implicitHeight: tooltipContent.implicitHeight + 2 * root.verticalPadding

    property bool isVisible: backgroundRectangle.implicitHeight > 0

    Rectangle {
        id: backgroundRectangle
        anchors {
            bottom: root.bottom
            horizontalCenter: root.horizontalCenter
        }
        color: Appearance?.colors.colTooltip ?? "#3C4043"
        radius: Appearance?.rounding.verysmall ?? 7
        opacity: shown ? 1 : 0
        implicitWidth: shown ? (tooltipContent.implicitWidth + 2 * root.horizontalPadding) : 0
        implicitHeight: shown ? (tooltipContent.implicitHeight + 2 * root.verticalPadding) : 0
        clip: true

        Behavior on implicitWidth {
            animation: Appearance?.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on implicitHeight {
            animation: Appearance?.animation.elementMoveFast.numberAnimation.createObject(this)
        }
        Behavior on opacity {
            animation: Appearance?.animation.elementMoveFast.numberAnimation.createObject(this)
        }

        RowLayout {
            id: tooltipContent
            anchors.centerIn: parent
            spacing: 6

            StyledText {
                id: tooltipTextObject
                text: root.text
                font.pixelSize: Appearance?.font.pixelSize.smaller ?? 14
                font.hintingPreference: Font.PreferNoHinting
                color: Appearance?.colors.colOnTooltip ?? "#FFFFFF"
                wrapMode: Text.Wrap
            }

            Kbd {
                visible: root.keys !== ""
                keys: root.keys
                textColor: Appearance?.colors.colOnTooltip ?? "#FFFFFF"
                lightBackground: true
            }
        }
    }
}

