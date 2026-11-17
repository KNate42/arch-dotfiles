-- window and layer rules
-- This work made by Anfinogentov Nikita

hl.window_rule({
    name = "suppress-maximize-events",
    match = { class = ".*" },
    suppress_event = "maximize",
})

hl.window_rule({
    name = "fix-xwayland-drags",
    match = { class = "^$", title = "^$", xwayland = true, float = true, fullscreen = false, pin = false },
    no_focus = true,
})

hl.window_rule({
    name = "float-small-tools",
    match = { class = "^(pavucontrol|org.pulseaudio.pavucontrol|nwg-look|qt6ct|blueman-manager)$" },
    float = true,
})

hl.layer_rule({
    name = "blur-rofi",
    match = { namespace = "^rofi$" },
    blur = true,
})

-- Здесь я размываю фон под стеклом оболочки (панель, меню питания, уведомления, OSD, выбор обоев);
-- ignore_alpha не размывает полностью прозрачные края, иначе вокруг скруглений видна серая рамка
hl.layer_rule({
    name = "blur-shell",
    match = { namespace = "^dots-.*$" },
    blur = true,
    ignore_alpha = 0.2,
})

hl.layer_rule({
    name = "fade-shell",
    match = { namespace = "^dots-(power|picker)$" },
    animation = "fade",
})
