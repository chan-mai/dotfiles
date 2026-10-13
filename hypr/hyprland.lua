-- 配色
local c = {
  base = "191724",
  overlay = "26233a",
  love = "eb6f92",
  pine = "31748f",
  foam = "9ccfd8",
  iris = "c4a7e7",
}

local mod = "SUPER"
-- UWSM管理下で起動
local run = "uwsm app -- "

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = "0.8" })

hl.env("XCURSOR_THEME", "Hachiware")
hl.env("XCURSOR_SIZE", "32")

hl.on("hyprland.start", function()
  hl.exec_cmd("wl-paste --watch cliphist store")
end)

hl.config({
  general = {
    gaps_in = 3,
    gaps_out = 8,
    border_size = 2,
    col = {
      active_border = { colors = { "rgba(" .. c.love .. "ff)", "rgba(" .. c.iris .. "ff)" }, angle = 45 },
      inactive_border = { colors = { "rgba(" .. c.pine .. "cc)", "rgba(" .. c.foam .. "cc)" }, angle = 45 },
    },
    layout = "dwindle",
    resize_on_border = true,
  },
  decoration = {
    rounding = 10,
    shadow = { enabled = false },
    blur = {
      enabled = true,
      size = 6,
      passes = 3,
      new_optimizations = true,
      ignore_opacity = true,
      xray = false,
    },
  },
  animations = { enabled = true },
  dwindle = { preserve_split = true },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
  },
  input = {
    kb_layout = "us",
    follow_mouse = 1,
  },
})

-- アプリ
hl.bind(mod .. " + T", hl.dsp.exec_cmd(run .. "ghostty"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd(run .. "dolphin"))
hl.bind(mod .. " + A", hl.dsp.exec_cmd("rofi -show drun -run-command '" .. run .. "{cmd}'"))
hl.bind(mod .. " + Tab", hl.dsp.exec_cmd("rofi -show window"))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("cliphist list | rofi -dmenu | cliphist decode | wl-copy"))
hl.bind(mod .. " + L", hl.dsp.exec_cmd("loginctl lock-session"))
hl.bind(mod .. " + BackSpace", hl.dsp.exec_cmd("wlogout"))
hl.bind("Print", hl.dsp.exec_cmd("grimblast copysave area"))
hl.bind(mod .. " + P", hl.dsp.exec_cmd("grimblast copysave area"))

-- ウィンドウ
hl.bind(mod .. " + Q", hl.dsp.window.close())
hl.bind(mod .. " + W", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen())
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))
for _, dir in ipairs({ "left", "right", "up", "down" }) do
  hl.bind(mod .. " + " .. dir, hl.dsp.focus({ direction = dir }))
  hl.bind(mod .. " + SHIFT + " .. dir, hl.dsp.window.move({ direction = dir }))
end
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- ワークスペース
for i = 1, 10 do
  local key = i % 10
  hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- メディアキー
local media = { locked = true, repeating = true }
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), media)
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), media)
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })
