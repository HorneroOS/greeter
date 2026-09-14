// BrandingMark.qml — small optional HorneroOS symbol overlay.
// Pure overlay: fixed corner placement by the parent, no layout,
// interaction, or behavior effects. Hidden unless branding is enabled
// and the logo file loads cleanly (a missing file degrades to pure
// upstream presentation, never a broken-image icon).
import QtQuick

Image {
    id: mark

    property bool brandingEnabled: true

    asynchronous: true
    fillMode: Image.PreserveAspectFit
    opacity: 0.8
    sourceSize.width: 96
    visible: brandingEnabled && status === Image.Ready
}
