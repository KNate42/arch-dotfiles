// Wallpaper picker overlay controlled via IPC and keyboard or mouse
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
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        implicitWidth: 820
        implicitHeight: 540
        color: "transparent"

        onVisibleChanged: {
            if (picker_window.visible) {
                wall_grid.forceActiveFocus();
            }
        }

        Rectangle {
            id: picker_card
            anchors.fill: parent
            radius: 14
            color: Colors.surface
            border.width: 2
            border.color: Colors.primary

            Text {
                id: title_label
                anchors {
                    top: parent.top
                    topMargin: 14
                    left: parent.left
                    leftMargin: 18
                }
                text: "󰸉 Select Wallpaper"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 15
                font.bold: true
                color: Colors.on_surface
            }

            GridView {
                id: wall_grid
                anchors {
                    top: title_label.bottom
                    topMargin: 12
                    left: parent.left
                    leftMargin: 16
                    right: parent.right
                    rightMargin: 16
                    bottom: parent.bottom
                    bottomMargin: 16
                }
                clip: true
                focus: true
                keyNavigationEnabled: true
                cellWidth: 196
                cellHeight: 140
                model: folder_model

                Keys.onEscapePressed: picker_root.is_open = false
                Keys.onReturnPressed: picker_root.apply_wallpaper(picker_root.current_file_path)
                Keys.onEnterPressed: picker_root.apply_wallpaper(picker_root.current_file_path)

                delegate: Rectangle {
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

                    width: 184
                    height: 128
                    radius: 8
                    color: thumb_delegate.is_selected ? Colors.primary_container : Colors.surface_container_high
                    border.width: thumb_delegate.is_selected ? 2 : 1
                    border.color: thumb_delegate.is_selected ? Colors.primary : Colors.outline_variant

                    Image {
                        id: thumb_image
                        anchors {
                            top: parent.top
                            topMargin: 6
                            left: parent.left
                            leftMargin: 6
                            right: parent.right
                            rightMargin: 6
                        }
                        height: 92
                        source: thumb_delegate.fileUrl
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 368
                        sourceSize.height: 184
                    }

                    Text {
                        id: thumb_name
                        anchors {
                            left: parent.left
                            leftMargin: 8
                            right: parent.right
                            rightMargin: 8
                            bottom: parent.bottom
                            bottomMargin: 6
                        }
                        text: thumb_delegate.fileName
                        font.family: "JetBrainsMono Nerd Font"
                        font.pixelSize: 11
                        color: thumb_delegate.is_selected ? Colors.on_primary_container : Colors.on_surface
                        elide: Text.ElideMiddle
                        horizontalAlignment: Text.AlignHCenter
                    }

                    MouseArea {
                        anchors.fill: parent
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
                text: "No wallpapers found in ~/Pictures/wallpapers"
                font.family: "JetBrainsMono Nerd Font"
                font.pixelSize: 13
                color: Colors.on_surface_variant
            }
        }
    }
}
