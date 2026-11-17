-- key bindings: apps, windows, workspaces, screenshots, wallpapers, media keys
-- This work made by Anfinogentov Nikita

local main_mod = "SUPER"
local terminal = "kitty"
local launcher = "rofi -show drun"
-- bin_dir = мои скрипты из пакета scripts; полный путь, чтобы не зависеть от PATH сессии
local bin_dir = (os.getenv("HOME") or "") .. "/.local/bin/"

local function key(combo)
    return main_mod .. " + " .. combo
end

hl.bind(key("Return"), hl.dsp.exec_cmd(terminal))
hl.bind(key("Q"), hl.dsp.window.close())
hl.bind(key("D"), hl.dsp.exec_cmd(launcher))
hl.bind(key("F"), hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(key("SHIFT + F"), hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(key("SPACE"), hl.dsp.window.float({ action = "toggle" }))
hl.bind(key("Escape"), hl.dsp.exec_cmd("pidof hyprlock || hyprlock"))
hl.bind(key("W"), hl.dsp.exec_cmd("qs ipc call wallpaper toggle"))
hl.bind(key("A"), hl.dsp.exec_cmd("qs ipc call control toggle"))
hl.bind(key("V"), hl.dsp.exec_cmd("cliphist list | rofi -dmenu -p clipboard -theme clipboard | cliphist decode | wl-copy"))
-- Здесь я открываю меню питания вместо мгновенного выхода: случайное нажатие больше не закрывает сессию
hl.bind(key("SHIFT + E"), hl.dsp.exec_cmd("qs ipc call power toggle"))
hl.bind(key("CTRL + SHIFT + E"), hl.dsp.exit())
hl.bind("Print", hl.dsp.exec_cmd(bin_dir .. "screenshot-area"))

-- Здесь я делаю фокус и перенос окон в стиле vim: H/J/K/L = влево/вниз/вверх/вправо
local directions = { H = "left", J = "down", K = "up", L = "right" }
for letter, direction in pairs(directions) do
    hl.bind(key(letter), hl.dsp.focus({ direction = direction }))
    hl.bind(key("SHIFT + " .. letter), hl.dsp.window.move({ direction = direction }))
end

for i = 1, 9 do
    hl.bind(key(tostring(i)), hl.dsp.focus({ workspace = i }))
    hl.bind(key("SHIFT + " .. i), hl.dsp.window.move({ workspace = i }))
end

hl.bind(key("mouse_down"), hl.dsp.focus({ workspace = "e+1" }))
hl.bind(key("mouse_up"), hl.dsp.focus({ workspace = "e-1" }))
hl.bind(key("mouse:272"), hl.dsp.window.drag(), { mouse = true })
hl.bind(key("mouse:273"), hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
