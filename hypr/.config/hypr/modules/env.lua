-- environment variables for the session: toolkits, cursor, Nvidia
-- This work made by Anfinogentov Nikita

-- Здесь я добавляю ~/.local/bin в PATH: оттуда хоткеи берут wallpaper-set, screenshot-area, tv-audio
local home = os.getenv("HOME") or ""
local path = os.getenv("PATH") or "/usr/local/bin:/usr/bin"
if not string.find(path, home .. "/.local/bin", 1, true) then
    hl.env("PATH", home .. "/.local/bin:" .. path)
end

hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")

hl.env("QT_QPA_PLATFORM", "wayland;xcb")
-- qt5ct понимают и Qt5, и Qt6 (плагин qt6ct регистрируется под обоими именами)
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("SDL_VIDEODRIVER", "wayland")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Здесь я включаю переменные Nvidia, только если драйвер реально загружен
local nvidia_file = io.open("/proc/driver/nvidia/version", "r")
if nvidia_file then
    nvidia_file:close()
    hl.env("LIBVA_DRIVER_NAME", "nvidia")
    hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
    hl.env("NVD_BACKEND", "direct")
end
