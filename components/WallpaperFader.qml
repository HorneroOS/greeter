/********************************************************************
 This file is part of the KDE project.

Copyright (C) 2014 Aleix Pol Gonzalez <aleixpol@blue-systems.com>

This program is free software; you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation; either version 2 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*********************************************************************/
// Qt6 port: QtGraphicalEffects (FastBlur + custom ShaderEffect) is gone.
// The blur/grade is reimplemented with the Qt6 QtQuick.Effects MultiEffect
// item. The default state is "off"; the old default expression referenced
// lockScreenRoot.uiVisible, which does not exist in an SDDM greeter.

import QtQuick
import QtQuick.Effects

Item {
    id: wallpaperFader
    property Item mainStack
    property Item footer
    property alias source: wallpaperEffect.source
    state: "off"
    property real factor: 0

    Behavior on factor {
        NumberAnimation {
            target: wallpaperFader
            property: "factor"
            duration: 1000
            easing.type: Easing.InOutQuad
        }
    }

    MultiEffect {
        id: wallpaperEffect
        anchors.fill: parent
        blurEnabled: true
        blur: wallpaperFader.factor
        blurMax: 32
        brightness: -0.15 * wallpaperFader.factor
        saturation: -0.4 * wallpaperFader.factor
        contrast: 0.1 * wallpaperFader.factor
    }

    states: [
        State {
            name: "on"
            PropertyChanges {
                target: mainStack
                opacity: 1
            }
            PropertyChanges {
                target: footer
                opacity: 1
            }
            PropertyChanges {
                target: wallpaperFader
                factor: 1
            }
        },
        State {
            name: "off"
            PropertyChanges {
                target: mainStack
                opacity: 0
            }
            PropertyChanges {
                target: footer
                opacity: 0
            }
            PropertyChanges {
                target: wallpaperFader
                factor: 0
            }
        }
    ]
    transitions: [
        Transition {
            from: "off"
            to: "on"
            //Note: can't use animators as they don't play well with parallelanimations
            ParallelAnimation {
                NumberAnimation {
                    target: mainStack
                    property: "opacity"
                    duration: 500
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: footer
                    property: "opacity"
                    duration: 500
                    easing.type: Easing.InOutQuad
                }
            }
        },
        Transition {
            from: "on"
            to: "off"
            ParallelAnimation {
                NumberAnimation {
                    target: mainStack
                    property: "opacity"
                    duration: 500
                    easing.type: Easing.InOutQuad
                }
                NumberAnimation {
                    target: footer
                    property: "opacity"
                    duration: 500
                    easing.type: Easing.InOutQuad
                }
            }
        }
    ]
}
