{
  pkgs,
  lib,
  ...
}:

let
  wallpaper = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/klpod221/klpod0s/2bb63e89ed734f984d07805a01183043197b5512/configs/.config/swww/Material-Sakura/material_pastel_4.jpg";
    hash = "sha256-yNWNLlZMkBD/UwDmLLh4Q0v8lC9DgRNoQWwmfCuEQAY=";
  };

  # パステルピンク配色(r,g,b)
  p = {
    bg = "253,240,245";
    bgAlt = "250,230,238";
    view = "255,250,252";
    viewAlt = "253,242,247";
    button = "250,224,235";
    buttonAlt = "246,212,226";
    header = "249,213,227";
    headerInactive = "251,231,239";
    tooltip = "255,245,249";
    accent = "217,96,143";
    hover = "240,150,190";
    text = "77,52,66";
    muted = "150,120,135";
    link = "196,80,140";
    visited = "150,90,170";
    negative = "214,69,90";
    neutral = "214,150,60";
    positive = "90,160,110";
    plum = "92,60,78";
    white = "255,255,255";
  };

  group = bg: bgAlt: fg: ''
    BackgroundNormal=${bg}
    BackgroundAlternate=${bgAlt}
    ForegroundNormal=${fg}
    ForegroundInactive=${p.muted}
    ForegroundActive=${p.accent}
    ForegroundLink=${p.link}
    ForegroundVisited=${p.visited}
    ForegroundNegative=${p.negative}
    ForegroundNeutral=${p.neutral}
    ForegroundPositive=${p.positive}
    DecorationFocus=${p.accent}
    DecorationHover=${p.hover}
  '';
in
{
  home.packages = [ pkgs.lucide-icon-theme ];

  xdg.dataFile."color-schemes/PastelPink.colors".text = ''
    [General]
    ColorScheme=PastelPink
    Name=Pastel Pink

    [KDE]
    contrast=4

    [Colors:Window]
    ${group p.bg p.bgAlt p.text}
    [Colors:View]
    ${group p.view p.viewAlt p.text}
    [Colors:Button]
    ${group p.button p.buttonAlt p.text}
    [Colors:Selection]
    ${group p.accent p.hover p.white}
    [Colors:Tooltip]
    ${group p.tooltip p.bgAlt p.text}
    [Colors:Header]
    ${group p.header p.bgAlt p.text}
    [Colors:Header][Inactive]
    ${group p.headerInactive p.bgAlt p.text}
    [Colors:Complementary]
    ${group p.plum p.plum "255,240,246"}
    [WM]
    activeBackground=${p.header}
    activeForeground=${p.text}
    activeBlend=${p.header}
    inactiveBackground=${p.headerInactive}
    inactiveForeground=${p.muted}
    inactiveBlend=${p.headerInactive}
  '';

  programs.plasma = {
    enable = true;

    workspace = {
      colorScheme = "PastelPink";
      iconTheme = "Lucide";
      cursor = {
        theme = "Hachiware";
        size = 32;
      };
      inherit wallpaper;
    };

    fonts.general = {
      family = "Noto Sans CJK JP";
      pointSize = 10;
    };

    kwin.virtualDesktops.number = 4;

    startup.startupScript.display.text = "kscreen-doctor output.HDMI-A-1.scale.0.8";

    # 曜日表記用
    configFile.plasma-localerc.Formats.LC_TIME = "ja_JP.UTF-8";

    panels = [
      {
        location = "top";
        height = 28;
        opacity = "translucent";
        widgets = [
          { kickoff.icon = "start-here"; }
          "org.kde.plasma.appmenu"
          "org.kde.plasma.panelspacer"
          "org.kde.plasma.systemtray"
          {
            digitalClock = {
              time.format = "24h";
              date = {
                enable = true;
                format.custom = "M月d日(ddd)";
                position = "besideTime";
              };
            };
          }
        ];
      }
      {
        location = "bottom";
        height = 52;
        floating = true;
        lengthMode = "fit";
        hiding = "dodgewindows";
        opacity = "translucent";
        widgets = [
          {
            iconTasks.launchers = [
              "applications:com.mitchellh.ghostty.desktop"
              "applications:org.kde.dolphin.desktop"
              "applications:google-chrome.desktop"
              "applications:code.desktop"
              "applications:org.prismlauncher.PrismLauncher.desktop"
              "applications:steam.desktop"
            ];
          }
        ];
      }
    ];

    hotkeys.commands.ghostty = {
      name = "Launch Ghostty";
      key = "Meta+T";
      command = "ghostty";
    };

    shortcuts = {
      kwin = {
        "Window Close" = "Meta+Q";
        "Window Fullscreen" = "Meta+F";
      };
      # Meta+Q重複回避
      plasmashell."manage activities" = [ ];
      "services/org.kde.krunner.desktop"._launch = [
        "Alt+Space"
        "Meta+A"
      ];
    };

    # GTK設定はhome-manager管理
    configFile.kded6rc.Module-gtkconfig.autoload = false;

    configFile.kscreenlockerrc."Greeter/Wallpaper/org.kde.image/General".Image = "${wallpaper}";

    kscreenlocker.autoLock = false;

    powerdevil.AC = {
      autoSuspend.action = "nothing";
      turnOffDisplay.idleTimeout = "never";
      dimDisplay.enable = false;
    };

    # Hyprlandのボーダー再現(KDE Rounded Corners)
    configFile.kwinrc = {
      Plugins.kwin4_effect_shapecornersEnabled = true;
      Round-Corners = {
        Size = 10;
        InactiveCornerRadius = 10;
        UseSquircleShape = false;
        OutlineThickness = 2;
        InactiveOutlineThickness = 2;
        OutlineIsGradient = true;
        InactiveOutlineIsGradient = true;
        # love → iris
        OutlineColor = "235,111,146";
        OutlineColor2 = "196,167,231";
        # pine → foam, 透明度cc
        InactiveOutlineColor = "49,116,143";
        InactiveOutlineColor2 = "156,207,216,204";
        InactiveOutlineAlpha = 204;
        SecondOutlineThickness = 0;
        InactiveSecondOutlineThickness = 0;
      };
    };
  };

  # Hyprland専用サービス, Plasmaでは起動しない
  systemd.user.services = lib.genAttrs [ "waybar" "hyprpaper" "hypridle" "dunst" ] (_: {
    Unit.ConditionEnvironment = lib.mkForce [
      "WAYLAND_DISPLAY"
      "XDG_CURRENT_DESKTOP=Hyprland"
    ];
  });
}
