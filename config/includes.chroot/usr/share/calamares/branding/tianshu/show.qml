import QtQuick 2.7

// 天枢 OS — 安装器欢迎页（三阶紫罗兰，唯一的「天枢」标识）
Rectangle {
    anchors.fill: parent

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#E2D0E8" }
            GradientStop { position: 0.55; color: "#D8D1E6" }
            GradientStop { position: 1.0; color: "#CEC5DB" }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: 18

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "天枢"
            color: "#2A2438"
            font.pixelSize: 110
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "玄之又玄，众妙之门"
            color: "#3A2C4A"
            font.pixelSize: 20
        }
    }
}
