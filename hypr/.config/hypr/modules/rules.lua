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
