import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

// TianShu OS — 极简无时钟登录界面（紫罗兰三阶）
Rectangle {
    id: root
    width: 1920
    height: 1080

    function doLogin() {
        if (userField.text.length > 0 && passField.text.length > 0) {
            sddm.login(userField.text, passField.text, sessionBox.currentText)
        }
    }

    gradient: Gradient {
        GradientStop { position: 0.0; color: "#E2D0E8" }
        GradientStop { position: 0.55; color: "#D8D1E6" }
        GradientStop { position: 1.0; color: "#CEC5DB" }
    }

    // 柔性光晕，避免纯色呆板
    Rectangle {
        width: parent.width * 0.55
        height: width
        radius: width / 2
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -parent.height * 0.12
        color: Qt.rgba(1, 1, 1, 0.18)
    }

    Rectangle {
        id: card
        width: 380
        height: 348
        anchors.centerIn: parent
        radius: 18
        color: Qt.rgba(1.0, 1.0, 1.0, 0.52)
        border.width: 1
        border.color: Qt.rgba(1.0, 1.0, 1.0, 0.78)

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 28
            spacing: 14

            Label {
                Layout.fillWidth: true
                text: qsTr("天枢 OS")
                font.pixelSize: 22
                font.bold: true
                color: "#3A2C4A"
                horizontalAlignment: Text.AlignHCenter
            }

            Label {
                Layout.fillWidth: true
                text: qsTr("TianShu Violet")
                font.pixelSize: 11
                color: "#6A5A7A"
                horizontalAlignment: Text.AlignHCenter
                Layout.bottomMargin: 6
            }

            TextField {
                id: userField
                Layout.fillWidth: true
                placeholderText: qsTr("用户名")
                text: typeof userModel !== "undefined" ? userModel.lastUser : ""
                font.pixelSize: 15
                selectByMouse: true
                onAccepted: passField.forceActiveFocus()
            }

            TextField {
                id: passField
                Layout.fillWidth: true
                placeholderText: qsTr("密码")
                echoMode: TextInput.Password
                font.pixelSize: 15
                selectByMouse: true
                onAccepted: root.doLogin()
            }

            ComboBox {
                id: sessionBox
                Layout.fillWidth: true
                model: typeof sessionModel !== "undefined" ? sessionModel : []
                textRole: "name"
                font.pixelSize: 13
            }

            Button {
                Layout.fillWidth: true
                text: qsTr("进入天枢")
                font.pixelSize: 15
                onClicked: root.doLogin()
            }
        }
    }

    Label {
        id: errorLabel
        anchors.top: card.bottom
        anchors.topMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        text: ""
        color: "#8E2F4A"
        font.pixelSize: 13
    }

    Connections {
        target: typeof sddm !== "undefined" ? sddm : null
        function onLoginFailed() {
            errorLabel.text = qsTr("认证失败，请重试")
            passField.text = ""
            passField.forceActiveFocus()
        }
        function onLoginSucceeded() {
            errorLabel.text = ""
        }
        function onInformationMessage(message) {
            errorLabel.text = message
        }
    }

    Component.onCompleted: {
        // 无时钟：界面刻意不渲染任何时间元素
        if (typeof userModel !== "undefined" && userModel.lastUser !== "") {
            passField.forceActiveFocus()
        } else {
            userField.forceActiveFocus()
        }
    }
}
