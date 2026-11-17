// HUD wallpaper browser with neon preview frames and keyboard or IPC control
// This work made by Anfinogentov Nikita

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import "../theme"

Scope {
    id: picker_root

    property bool is_open: false
    property string selected_path: ""
    property string current_file_path: ""

    readonly property string home_dir: Quickshell.env("HOME") ?? ""
    readonly property string wallpapers_dir: picker_root.home_dir + "/Pictures/wallpapers"

    function toggle_picker() {
        picker_root.is_open = !picker_root.is_open;
        if (picker_root.is_open) {
            wall_grid.forceActiveFocus();
            picker_title.glitch();
        }
    }

    function apply_wallpaper(full_path) {
        if (!full_path || full_path === "") {
            return;
        }
        picker_root.selected_path = full_path;
        wallpaper_proc.running = false;
        wallpaper_proc.running = true;
        picker_root.is_open = false;
    }

    IpcHandler {
        target: "wallpaper"

        function toggle(): void {
            picker_root.toggle_picker();
        }
    }

    Process {
        id: wallpaper_proc // proc = process
        command: [Quickshell.env("HOME") + "/.local/bin/wallpaper-set", picker_root.selected_path]
    }

    FolderListModel {
        id: folder_model
        folder: "file://" + picker_root.wallpapers_dir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.JPG", "*.JPEG", "*.PNG", "*.WEBP"]
        showDirs: false
        showDotAndDotDot: false
        showHidden: false
        sortField: FolderListModel.Name
    }

    PanelWindow {
        id: picker_window
        visible: picker_root.is_open
        focusable: true
        aboveWindows: true
        exclusiveZone: 0
        WlrLayershell.namespace: "dots-picker"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        implicitWidth: Style.space_xl * 34
        implicitHeight: Style.space_xl * 22
        color: "transparent"

        onVisibleChanged: {
            if (picker_window.visible) {
                wall_grid.forceActiveFocus();
            }
        }

        HudPanel {
            id: picker_card
            anchors.fill: parent
            accent: Colors.cyan
            active: true

            // Здесь я запускаю сбой заголовка при открытии, не меняя IPC и команду применения.
            Row {
                id: header_row
                anchors {
                    top: parent.top
                    topMargin: Style.space_lg
                    left: parent.left
                    leftMargin: Style.space_lg
                }
                spacing: Style.space_sm

                Text {
                    id: title_icon
                    anchors.verticalCenter: parent.verticalCenter
                    text: "󰸉"
                    font.family: Style.font_hud
                    font.capitalization: Font.AllUppercase
                    font.letterSpacing: Style.hud_letter_spacing
                    font.pixelSize: Style.text_lg
                    color: Colors.primary
                }

                NeonText {
                    id: picker_title
                    anchors.verticalCenter: parent.verticalCenter
                    text: ">> WALLPAPER.SELECT"
                    pixel_size: Style.text_lg
                    color: Colors.cyan
                }
            }

            GridView {
                id: wall_grid
                anchors {
                    top: header_row.bottom
                    topMargin: Style.space_md
                    left: parent.left
                    leftMargin: Style.space_lg
                    right: parent.right
                    rightMargin: Style.space_lg
                    bottom: parent.bottom
                    bottomMargin: Style.space_lg
                }
                clip: true
                focus: true
                keyNavigationEnabled: true
                onCurrentIndexChanged: { if (picker_root.is_open) picker_title.glitch(); }
                cellWidth: Style.space_xl * 8
                cellHeight: Style.space_xl * 6
                model: folder_model

                Keys.onEscapePressed: picker_root.is_open = false
                Keys.onReturnPressed: picker_root.apply_wallpaper(picker_root.current_file_path)
                Keys.onEnterPressed: picker_root.apply_wallpaper(picker_root.current_file_path)

                delegate: HudPanel {
                    id: thumb_delegate // thumb = thumbnail
                    required property int index
                    required property string filePath
                    required property string fileName
                    required property url fileUrl

                    readonly property bool is_selected: wall_grid.currentIndex === thumb_delegate.index

                    // Здесь я синхронизирую путь выбранного элемента, чтобы нажатие Enter передавало актуальный файл в Process
                    onIs_selectedChanged: {
                        if (thumb_delegate.is_selected) {
                            picker_root.current_file_path = thumb_delegate.filePath;
                        }
                    }

                    onFilePathChanged: {
                        if (thumb_delegate.is_selected) {
                            picker_root.current_file_path = thumb_delegate.filePath;
                        }
                    }

                    Component.onCompleted: {
                        if (thumb_delegate.is_selected) {
                            picker_root.current_file_path = thumb_delegate.filePath;
                        }
                    }

                    width: Style.space_xl * 8 - Style.space_sm
                    height: Style.space_xl * 6 - Style.space_md
                    cut: 8
                    brackets: false
                    scanlines: false
                    accent: is_selected ? Colors.magenta : Colors.cyan
                    active: is_selected || thumb_mouse.containsMouse
                    // Здесь я отделяю выбранную рамку от наведения, сохраняя выбор с клавиатуры.

                    Image {
                        id: thumb_image
                        anchors {
                            top: parent.top
                            topMargin: Style.space_sm
                            left: parent.left
                            leftMargin: Style.space_sm
                            right: parent.right
                            rightMargin: Style.space_sm
                        }
                        height: Style.space_xl * 4
                        source: thumb_delegate.fileUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: Style.space_xl * 15
                        sourceSize.height: Style.space_xl * 8
                    }

                    Text {
                        id: thumb_name
                        anchors {
                            left: parent.left
                            leftMargin: Style.space_sm
                            right: parent.right
                            rightMargin: Style.space_sm
                            bottom: parent.bottom
                            bottomMargin: Style.space_sm
                        }
                        text: thumb_delegate.fileName
                        font.family: Style.font_hud
                        font.capitalization: Font.AllUppercase
                        font.letterSpacing: Style.hud_letter_spacing
                        font.pixelSize: Style.text_xs
                        color: thumb_delegate.is_selected ? Colors.magenta : Colors.on_surface
                        elide: Text.ElideMiddle
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        id: thumb_mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            wall_grid.currentIndex = thumb_delegate.index;
                            picker_root.apply_wallpaper(thumb_delegate.filePath);
                        }
                    }
                }
            }

            Text {
                id: empty_label
                anchors.centerIn: parent
                visible: folder_model.count === 0
                text: "// NO WALLPAPERS IN ~/Pictures/wallpapers"
                font.family: Style.font_hud
                font.capitalization: Font.AllUppercase
                font.letterSpacing: Style.hud_letter_spacing
                font.pixelSize: Style.text_md
                color: Colors.on_surface_variant
            }
        }
    }
}
