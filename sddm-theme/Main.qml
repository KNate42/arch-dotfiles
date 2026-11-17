// Main SDDM greeter screen for Qt6 with Material You palette
// This work made by Anfinogentov Nikita

import QtQuick
import QtQuick.Controls

Rectangle {
    id: root_pane
    width: 1920
    height: 1080
    color: surface_color

    readonly property string font_family: "Inter"

    // Здесь я делаю цвет полупрозрачным для стеклянных карточек и мягких кнопок
    function alpha(base, amount) {
        return Qt.rgba(base.r, base.g, base.b, amount)
    }

    readonly property string bg_source: (typeof config !== "undefined" && config && config.background) ? config.background : "background.jpg"
    readonly property color primary_color: (typeof config !== "undefined" && config && config.primary) ? config.primary : "#89b4fa"
    readonly property color on_primary_color: (typeof config !== "undefined" && config && config.on_primary) ? config.on_primary : "#11111b"
    readonly property color surface_color: (typeof config !== "undefined" && config && config.surface) ? config.surface : "#1e1e2e"
    readonly property color on_surface_color: (typeof config !== "undefined" && config && config.on_surface) ? config.on_surface : "#cdd6f4"
    readonly property color surface_container_color: (typeof config !== "undefined" && config && config.surface_container) ? config.surface_container : "#313244"
    readonly property color outline_color: (typeof config !== "undefined" && config && config.outline) ? config.outline : "#585b70"
    readonly property color error_color: (typeof config !== "undefined" && config && config.error) ? config.error : "#f38ba8"

    property string current_time_text: Qt.formatTime(new Date(), "HH:mm")
    property string current_date_text: Qt.formatDate(new Date(), "dddd, d MMMM")
    property string error_text: ""

    readonly property string selected_user: {
        if (user_combo.currentText !== "") {
            return user_combo.currentText
        }
        if (typeof userModel !== "undefined" && userModel && userModel.lastUser) {
            return userModel.lastUser
        }
        return ""
    }

    function session_field(idx, role_num, use_text_at) {
        if (use_text_at && session_combo && idx >= 0 && idx < session_combo.count) {
            var combo_text = session_combo.textAt(idx)
            if (combo_text) {
                return String(combo_text)
            }
        }
        if (typeof sessionModel !== "undefined" && sessionModel && sessionModel.index && sessionModel.data) {
            var val = sessionModel.data(sessionModel.index(idx, 0), role_num)
            if (val !== undefined && val !== null) {
                return String(val)
            }
        }
        return ""
    }

    // В SDDM SessionModel: FileRole = Qt::UserRole + 2 (258), NameRole = Qt::UserRole + 4 (260)
    function session_is_uwsm(idx) {
        var file_name = session_field(idx, 258, false).toLowerCase()
        var title = session_field(idx, 260, true).toLowerCase()
        return file_name.indexOf("uwsm") !== -1 || title.indexOf("uwsm") !== -1
    }

    // Здесь я ищу обычную сессию Hyprland без uwsm: uwsm не ставится, а по алфавиту hyprland-uwsm.desktop идёт первым
    function find_hyprland_session() {
        var total = session_combo ? session_combo.count : 0
        if (total <= 0 && typeof sessionModel !== "undefined" && sessionModel) {
            if (sessionModel.rowCount) {
                total = sessionModel.rowCount()
            } else if (sessionModel.count !== undefined) {
                total = sessionModel.count
            }
        }
        for (var i = 0; i < total; i++) {
            var file_name = session_field(i, 258, false).toLowerCase()
            var title = session_field(i, 260, true).toLowerCase()
            var has_hyprland = file_name.indexOf("hyprland") !== -1 || title.indexOf("hyprland") !== -1
            if (has_hyprland && !session_is_uwsm(i)) {
                return i
            }
        }
        return 0
    }

    function default_session_index() {
        if (typeof sessionModel !== "undefined" && sessionModel
            && sessionModel.lastIndex !== undefined && sessionModel.lastIndex !== null
            && sessionModel.lastIndex >= 0 && !session_is_uwsm(sessionModel.lastIndex)) {
            return sessionModel.lastIndex
        }
        return find_hyprland_session()
    }

    readonly property int selected_session: {
        if (session_combo.currentIndex >= 0) {
            return session_combo.currentIndex
        }
        return default_session_index()
    }

    readonly property string keyboard_layout_label: {
        if (typeof keyboard !== "undefined" && keyboard && keyboard.layouts && keyboard.layouts.length > 0) {
            var layout_idx = keyboard.currentLayout
            if (layout_idx >= 0 && layout_idx < keyboard.layouts.length) {
                return keyboard.layouts[layout_idx].shortName.toUpperCase()
            }
        }
        return "US"
    }

    function update_clock() {
        var now_date = new Date()
        current_time_text = Qt.formatTime(now_date, "HH:mm")
        current_date_text = Qt.formatDate(now_date, "dddd, d MMMM")
    }

    function cycle_keyboard_layout() {
        if (typeof keyboard !== "undefined" && keyboard && keyboard.layouts && keyboard.layouts.length > 1) {
            keyboard.currentLayout = (keyboard.currentLayout + 1) % keyboard.layouts.length
        }
    }

    function try_login() {
        error_text = ""
        sddm.login(selected_user, password_field.text, selected_session)
    }

    Timer {
        id: clock_timer
        interval: 1000
        running: true
        repeat: true
        onTriggered: root_pane.update_clock()
    }

    Connections {
        target: sddm

        function onLoginFailed() {
            root_pane.error_text = "Ooops.. wrong password"
            password_field.text = ""
            password_field.forceActiveFocus()
        }

        function onLoginSucceeded() {
            root_pane.error_text = ""
        }
    }

    // Здесь я скрываю картинку, если файл обоев отсутствует или не загрузился, оставляя сплошной цвет surface
    Image {
        id: wallpaper_image
        anchors.fill: parent
        source: root_pane.bg_source
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        visible: status === Image.Ready
    }

    Rectangle {
        id: wallpaper_dim
        anchors.fill: parent
        color: root_pane.surface_color
        opacity: 0.45
        visible: wallpaper_image.visible
    }

    Column {
        id: center_column
        anchors.centerIn: parent
        width: 380
        spacing: 28

        Column {
            id: clock_column
            width: parent.width
            spacing: 6

            Text {
                id: time_label
                anchors.horizontalCenter: parent.horizontalCenter
                text: root_pane.current_time_text
                color: root_pane.on_surface_color
                font.family: root_pane.font_family
                font.pixelSize: 96
                font.weight: Font.Light
            }

            Text {
                id: date_label
                anchors.horizontalCenter: parent.horizontalCenter
                text: root_pane.current_date_text
                color: root_pane.on_surface_color
                opacity: 0.80
                font.family: root_pane.font_family
                font.pixelSize: 18
            }
        }

        // Стеклянная карточка входа с полупрозрачным фоном и тонкой рамкой
        Rectangle {
            id: login_card
            width: parent.width
            height: card_column.implicitHeight + 48
            radius: 18
            color: root_pane.alpha(root_pane.surface_container_color, 0.72)
            border.width: 1
            border.color: root_pane.alpha(root_pane.outline_color, 0.35)

            Column {
                id: card_column
                anchors.fill: parent
                anchors.margins: 24
                spacing: 16

                Text {
                    id: single_user_label
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: !user_combo.visible && root_pane.selected_user !== ""
                    text: root_pane.selected_user
                    color: root_pane.on_surface_color
                    opacity: 0.90
                    font.family: root_pane.font_family
                    font.pixelSize: 15
                    font.weight: Font.Medium
                }

                // Здесь я показываю выпадающий список только если в системе больше одного пользователя
                ComboBox {
                    id: user_combo
                    width: parent.width
                    height: 44
                    visible: (typeof userModel !== "undefined" && userModel) ? userModel.count > 1 : false
                    model: typeof userModel !== "undefined" ? userModel : null
                    textRole: "name"
                    currentIndex: (typeof userModel !== "undefined" && userModel && userModel.lastIndex >= 0) ? userModel.lastIndex : 0
                    font.family: root_pane.font_family
                    font.pixelSize: 14

                    contentItem: Text {
                        leftPadding: 14
                        rightPadding: 28
                        text: user_combo.displayText
                        font: user_combo.font
                        color: root_pane.on_surface_color
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                    }

                    background: Rectangle {
                        radius: 12
                        color: root_pane.alpha(root_pane.surface_color, 0.65)
                        border.width: 1
                        border.color: user_combo.activeFocus
                            ? root_pane.alpha(root_pane.primary_color, 0.65)
                            : root_pane.alpha(root_pane.outline_color, 0.35)
                    }
                }

                TextField {
                    id: password_field
                    width: parent.width
                    height: 46
                    focus: true
                    echoMode: TextInput.Password
                    placeholderText: "Password"
                    placeholderTextColor: root_pane.alpha(root_pane.on_surface_color, 0.45)
                    color: root_pane.on_surface_color
                    selectionColor: root_pane.primary_color
                    selectedTextColor: root_pane.on_primary_color
                    font.family: root_pane.font_family
                    font.pixelSize: 15
                    leftPadding: 16
                    rightPadding: 16
                    verticalAlignment: TextInput.AlignVCenter
                    onAccepted: root_pane.try_login()

                    background: Rectangle {
                        id: password_bg
                        radius: 14
                        color: root_pane.alpha(root_pane.surface_color, 0.65)
                        border.width: 1
                        border.color: root_pane.error_text !== ""
                            ? root_pane.error_color
                            : (password_field.activeFocus
                                ? root_pane.alpha(root_pane.primary_color, 0.65)
                                : root_pane.alpha(root_pane.outline_color, 0.35))
                    }
                }

                Button {
                    id: login_button
                    width: parent.width
                    height: 44
                    text: "Sign in"
                    font.family: root_pane.font_family
                    font.pixelSize: 15
                    font.weight: Font.Medium
                    onClicked: root_pane.try_login()

                    contentItem: Text {
                        text: login_button.text
                        font: login_button.font
                        color: root_pane.on_primary_color
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        id: login_button_bg
                        radius: 14
                        color: root_pane.alpha(
                            root_pane.primary_color,
                            login_button.down ? 0.75 : (login_button.hovered ? 0.92 : 0.84)
                        )
                        border.width: 1
                        border.color: root_pane.alpha(root_pane.primary_color, 0.40)
                    }
                }

                Text {
                    id: error_label
                    width: parent.width
                    visible: root_pane.error_text !== ""
                    text: root_pane.error_text
                    color: root_pane.error_color
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    font.family: root_pane.font_family
                    font.pixelSize: 13
                }
            }
        }
    }

    Item {
        id: bottom_bar
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        height: 44

        Row {
            id: session_row
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            ComboBox {
                id: session_combo
                width: 210
                height: 40
                model: typeof sessionModel !== "undefined" ? sessionModel : null
                textRole: "name"
                currentIndex: root_pane.default_session_index()
                font.family: root_pane.font_family
                font.pixelSize: 13

                contentItem: Text {
                    leftPadding: 14
                    rightPadding: 28
                    text: session_combo.displayText
                    font: session_combo.font
                    color: root_pane.on_surface_color
                    verticalAlignment: Text.AlignVCenter
                    elide: Text.ElideRight
                }

                background: Rectangle {
                    radius: 14
                    color: root_pane.alpha(root_pane.surface_container_color, 0.65)
                    border.width: 1
                    border.color: session_combo.activeFocus
                        ? root_pane.alpha(root_pane.primary_color, 0.60)
                        : root_pane.alpha(root_pane.outline_color, 0.30)
                }
            }

            Rectangle {
                id: layout_badge
                width: 56
                height: 40
                radius: 14
                color: root_pane.alpha(
                    root_pane.surface_container_color,
                    layout_mouse.containsMouse ? 0.80 : 0.65
                )
                border.width: 1
                border.color: root_pane.alpha(root_pane.outline_color, 0.30)

                Text {
                    id: layout_text
                    anchors.centerIn: parent
                    text: root_pane.keyboard_layout_label
                    color: root_pane.on_surface_color
                    font.family: root_pane.font_family
                    font.pixelSize: 13
                    font.weight: Font.Medium
                }

                MouseArea {
                    id: layout_mouse
                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: root_pane.cycle_keyboard_layout()
                }
            }
        }

        Row {
            id: power_row
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12

            Button {
                id: reboot_button
                width: 120
                height: 40
                text: "Reboot"
                font.family: root_pane.font_family
                font.pixelSize: 13
                onClicked: sddm.reboot()

                contentItem: Text {
                    text: reboot_button.text
                    font: reboot_button.font
                    color: root_pane.alpha(root_pane.on_surface_color, 0.90)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    id: reboot_bg
                    radius: 14
                    color: root_pane.alpha(
                        root_pane.surface_container_color,
                        reboot_button.down ? 0.85 : (reboot_button.hovered ? 0.78 : 0.65)
                    )
                    border.width: 1
                    border.color: reboot_button.hovered
                        ? root_pane.alpha(root_pane.primary_color, 0.50)
                        : root_pane.alpha(root_pane.outline_color, 0.30)
                }
            }

            Button {
                id: poweroff_button
                width: 120
                height: 40
                text: "Power Off"
                font.family: root_pane.font_family
                font.pixelSize: 13
                onClicked: sddm.powerOff()

                contentItem: Text {
                    text: poweroff_button.text
                    font: poweroff_button.font
                    color: poweroff_button.hovered
                        ? root_pane.error_color
                        : root_pane.alpha(root_pane.on_surface_color, 0.90)
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }

                background: Rectangle {
                    id: poweroff_bg
                    radius: 14
                    color: root_pane.alpha(
                        root_pane.surface_container_color,
                        poweroff_button.down ? 0.85 : (poweroff_button.hovered ? 0.78 : 0.65)
                    )
                    border.width: 1
                    border.color: poweroff_button.hovered
                        ? root_pane.alpha(root_pane.error_color, 0.55)
                        : root_pane.alpha(root_pane.outline_color, 0.30)
                }
            }
        }
    }

    Component.onCompleted: {
        session_combo.currentIndex = default_session_index()
        update_clock()
        password_field.forceActiveFocus()
    }
}
