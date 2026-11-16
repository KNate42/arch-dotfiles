-- autostart: wallpaper daemon, shell, idle daemon, polkit agent, clipboard history
-- This work made by Anfinogentov Nikita

local gtk_settings = {
    { "color-scheme", "prefer-dark" },
    { "gtk-theme", "adw-gtk3-dark" },
    { "icon-theme", "Papirus-Dark" },
    { "cursor-theme", "Bibata-Modern-Classic" },
    { "font-name", "JetBrainsMono Nerd Font 10" },
}

hl.on("hyprland.start", function()
    -- Здесь я на всякий случай отдаю окружение сессии в D-Bus и systemd: без него не стартуют порталы
    hl.exec_cmd("dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP HYPRLAND_INSTANCE_SIGNATURE")
    hl.exec_cmd("awww-daemon")
    hl.exec_cmd("quickshell")
    hl.exec_cmd("hypridle")
    hl.exec_cmd("systemctl --user start hyprpolkitagent")
    hl.exec_cmd("wl-paste --watch cliphist store")
    -- Здесь я возвращаю последние обои и тему GTK: gsettings работает только внутри сессии
    hl.exec_cmd((os.getenv("HOME") or "") .. "/.local/bin/wallpaper-set --restore")
    for _, pair in ipairs(gtk_settings) do
        hl.exec_cmd("gsettings set org.gnome.desktop.interface " .. pair[1] .. " \"" .. pair[2] .. "\"")
    end
end)
