-- monitors: main screen, Samsung TV on the right, hotplug reactions
-- This work made by Anfinogentov Nikita

-- tv_desc = начало описания телевизора из `hyprctl monitors all` (поле description)
local tv_desc = "Samsung Electric Company"
local tv_workspaces = { 6, 7, 8, 9 }
local tv_audio = (os.getenv("HOME") or "") .. "/.local/bin/tv-audio"

-- Любой монитор без своего правила: родное разрешение, справа от остальных
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

hl.monitor({ output = "desc:" .. tv_desc, mode = "preferred", position = "auto-right", scale = 1 })

for _, ws in ipairs(tv_workspaces) do
    hl.workspace_rule({ workspace = tostring(ws), monitor = "desc:" .. tv_desc })
end

local function is_tv(monitor)
    return monitor ~= nil and monitor.description ~= nil
        and string.find(monitor.description, tv_desc, 1, true) == 1
end

local function main_monitor_name(except_name)
    for _, monitor in ipairs(hl.get_monitors()) do
        if monitor.name ~= except_name and not is_tv(monitor) then
            return monitor.name
        end
    end
    return nil
end

-- Здесь я при подключении ТВ переношу на него его воркспейсы и переключаю звук на HDMI
hl.on("monitor.added", function(monitor)
    if not is_tv(monitor) then
        return
    end
    for _, ws in ipairs(tv_workspaces) do
        hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(ws), monitor = monitor.name }))
    end
    hl.exec_cmd(tv_audio .. " on")
    hl.notification.create({ text = "TV connected: " .. monitor.name, timeout = 3000, icon = "ok" })
end)

-- При отключении ТВ возвращаю звук; воркспейсы Hyprland сам переносит на оставшийся экран
hl.on("monitor.removed", function(monitor)
    if not is_tv(monitor) then
        return
    end
    local main_name = main_monitor_name(monitor.name)
    if main_name ~= nil then
        hl.dispatch(hl.dsp.focus({ monitor = main_name }))
    end
    hl.exec_cmd(tv_audio .. " off")
end)

-- Здесь я ловлю ТВ, включённый ещё до входа в сессию: событие подключения для него может не прийти
hl.on("hyprland.start", function()
    for _, monitor in ipairs(hl.get_monitors()) do
        if is_tv(monitor) then
            hl.exec_cmd(tv_audio .. " on")
            return
        end
    end
end)
