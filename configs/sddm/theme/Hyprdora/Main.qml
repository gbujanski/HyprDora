import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Window 2.15

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: "black"

    property string savedUsername: ""
    property color terminalDefaultColor: "#00ee00"
    property color terminalErrorColor: "#ff0000"
    property color terminalColor: root.terminalDefaultColor
    property int fontsize: 16
    property string fontfamily: "monospace"

    Timer {
        id: errorTimer
        interval: 500
        repeat: false
        onTriggered: root.terminalColor = terminalDefaultColor
    }

    Connections {
        target: sddm
        function onLoginFailed() {
            root.terminalColor = terminalErrorColor
            root.savedUsername = ""
            consoleInput.text = ""
            errorTimer.start()
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 10

        Column {
            Text {
                text: ">:"
                color: root.terminalColor
                font.family: root.fontfamily
                font.pixelSize: root.fontsize
                font.bold: true
            }
        }

        Column {
            TextInput {
                id: consoleInput
                color: root.terminalColor
                font.family: root.fontfamily
                font.pixelSize: root.fontsize
                focus: true
                width: 300
                
                cursorDelegate: Rectangle {
                    id: cursorBlock
                    width: 8
                    height: 32
                    color: root.terminalColor

                    Timer {
                        interval: 500
                        running: true
                        repeat: true
                        onTriggered: cursorBlock.visible = !cursorBlock.visible
                    }
                }

                echoMode: root.savedUsername === "" ? TextInput.Normal : TextInput.NoEcho

                onAccepted: {
                    if (root.savedUsername === "") {
                        
                        if (text.startsWith("/")) {
                            let cmd = text.substring(1).toLowerCase() 
                            
                            if (cmd === "poweroff") {
                                sddm.powerOff()
                            } 
                            else if (cmd === "reboot") {
                                sddm.reboot()
                            } 
                            else if (cmd === "suspend") {
                                sddm.suspend()
                            } 
                            else if (cmd === "help") {
                                helpMenu.visible = !helpMenu.visible
                            }
                            
                            text = "" 
                        } 
                        else {
                            root.savedUsername = text
                            text = ""
                        }
                    } else {
                        sddm.login(root.savedUsername, text, sddm.defaultSession)
                    }
                }
            }
        }
    }

    Text {
        id: helpMenu
        visible: false
        
        color: root.terminalColor
        
        font.family: root.fontfamily 
        font.pixelSize: root.fontsize
        
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 20
        
        text: "SYSTEM CMDS:   /help   |   /poweroff   |   /reboot   |   /suspend"
    }
}