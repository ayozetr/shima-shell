pragma Singleton
import Quickshell

// How much room the dock takes at its edge, so other windows can stay
// out of it. The launcher covers the whole screen to catch a click
// anywhere, which would otherwise swallow every click meant for the
// dock underneath.
Singleton {
    id: root
    property int reserved: 0
    property string position: "bottom"
}
