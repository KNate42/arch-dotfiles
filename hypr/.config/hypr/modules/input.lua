-- keyboard and mouse: us/ru layouts, layout switch on Alt+Shift
-- This work made by Anfinogentov Nikita

hl.config({
    input = {
        kb_layout = "us,ru",
        kb_variant = ",",
        kb_options = "grp:alt_shift_toggle",
        follow_mouse = 1,
        sensitivity = 0,
        numlock_by_default = true,
        repeat_delay = 300,
        repeat_rate = 40,
    },
})
