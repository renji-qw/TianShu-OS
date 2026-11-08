import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15 // 引入 Window 模块以获取屏幕尺寸

// TianShu OS — 极简无时钟登录界面（紫罗兰三阶）
Rectangle {
    id: root
    // 动态获取当前屏幕的分辨率，完美适配任何显示器
    width: Screen.width
    height: Screen.height

    function doLogin() {
        if (userField.text.length > 0 && passField.text.length > 0) {
            sddm.login(userField.text, passField.text, sessionBox.currentText)
        }
    }

    // 三阶紫罗兰微光渐变
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
        color: Qt.rgba(1, 1, 1,0.18)
    }

    // 居中悬浮的毛玻璃卡片
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

    // 错误提示（隐藏在卡片下方）
    Label {
        id: errorLabel
        anchors.top: card.bottom
        anchors.topMargin: 16
        anchors.horizontalCenter: parent.horizontalCenter
        text: ""
        color: "#8E2F4A"
        font.pixelSize: 13
    }

    // 监听 SDDM 状态事件
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

    // 初始化聚焦逻辑
    Component.onCompleted: {
        // 无时钟：界面刻意不渲染任何时间元素
        if (typeof userModel !== "undefined" && userModel.lastUser !== "") {
            passField.forceActiveFocus()
        } else {
            userField.forceActiveFocus()
        }
    }
}
