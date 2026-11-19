import QtQuick

// The sound controls, the same in the action center and in the sound panel under the bar's sound icon: the
// output's and the microphone's volume, each unfolding into its devices and the applications using it.
Column {
    id: root

    // Whether both sections start unfolded; each can then be folded on its own.
    property bool expanded: false
    // Whether unfolding one section folds the other, so only one is open at a time.
    property bool exclusive: false

    spacing: 0

    AudioSection {
        id: output
        width: root.width
        expanded: root.expanded
        onExpandedChanged: {
            if (expanded && root.exclusive)
                microphone.expanded = false;
        }
    }

    AudioSection {
        id: microphone
        width: root.width
        isMicrophone: true
        expanded: root.expanded
        onExpandedChanged: {
            if (expanded && root.exclusive)
                output.expanded = false;
        }
    }
}
