{
  config,
  pkgs,
  dotfiles-assets,
  ...
}:

let
  dotfiles = "${config.home.homeDirectory}/dotfiles";
  # レポジトリ内ファイル直リン
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";

  # klpod0sテーマ素材
  klpod0s = "https://raw.githubusercontent.com/klpod221/klpod0s/2bb63e89ed734f984d07805a01183043197b5512";
  wallpaper = pkgs.fetchurl {
    url = "${klpod0s}/configs/.config/swww/Material-Sakura/material_pastel_4.jpg";
    hash = "sha256-yNWNLlZMkBD/UwDmLLh4Q0v8lC9DgRNoQWwmfCuEQAY=";
  };

  # 配色
  c = {
    base = "191724";
    surface = "1f1d2e";
    overlay = "26233a";
    muted = "6e6a86";
    subtle = "908caa";
    text = "e0def4";
    love = "eb6f92";
    gold = "f6c177";
    rose = "ebbcba";
    pine = "31748f";
    foam = "9ccfd8";
    iris = "c4a7e7";
  };
in
{
  imports = [ ../../../modules/home.nix ];

  home.stateVersion = "26.11";

  xdg.configFile."ghostty/config".source = link "ghostty/config.ghostty";

  home.packages = with pkgs; [
    cliphist
    grimblast
    playerctl
  ];

  # 外観
  gtk = {
    enable = true;
    theme = {
      name = "adw-gtk3";
      package = pkgs.adw-gtk3;
    };
    font = {
      name = "Noto Sans CJK JP";
      size = 10;
    };
    iconTheme = {
      name = "Tela-circle-pink";
      package = pkgs.tela-circle-icon-theme.override { colorVariants = [ "pink" ]; };
    };
  };
  qt = {
    enable = true;
    platformTheme.name = "gtk3";
  };
  home.pointerCursor = {
    enable = true;
    name = "Hachiware";
    package = pkgs.callPackage ../../../packages/hachiware-cursor {
      src = "${dotfiles-assets}/hachiware-cursor.zip";
    };
    size = 32;
    gtk.enable = true;
  };

  # Hyprland本体はNixOS側, 設定はLua
  xdg.configFile."hypr/hyprland.lua".source = link "hypr/hyprland.lua";

  services.hyprpaper = {
    enable = true;
    settings = {
      splash = false;
      wallpaper = [
        {
          monitor = "";
          path = "${wallpaper}";
        }
      ];
    };
  };

  programs.waybar = {
    enable = true;
    systemd.enable = true;
    settings.main = {
      layer = "top";
      position = "top";
      height = 34;
      margin-top = 6;
      margin-left = 8;
      margin-right = 8;
      modules-left = [
        "hyprland/workspaces"
        "hyprland/window"
      ];
      modules-center = [ "clock" ];
      modules-right = [
        "tray"
        "cpu"
        "memory"
        "custom/gpu"
        "pulseaudio"
        "network"
      ];
      "hyprland/window".max-length = 40;
      clock = {
        format = "  {:%H:%M}";
        format-alt = "  {:%Y-%m-%d}";
      };
      cpu.format = "  {usage}%";
      memory.format = "  {percentage}%";
      "custom/gpu" = {
        exec = "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits | awk -F', ' '{print \"󰢮  \"$1\"% \"$2\"°C\"}'";
        interval = 5;
      };
      pulseaudio = {
        format = "{icon}  {volume}%";
        format-muted = "󰝟  muted";
        format-icons.default = [
          ""
          ""
          ""
        ];
        on-click = "pavucontrol";
      };
      network = {
        format-wifi = "  {essid}";
        format-ethernet = "󰈀  {ipaddr}";
        format-disconnected = "󰖪  offline";
      };
      tray.spacing = 8;
    };
    style = ''
      * {
        font-family: "BlexMono Nerd Font", "Noto Sans CJK JP", sans-serif;
        font-size: 13px;
        min-height: 0;
      }
      window#waybar {
        background: transparent;
      }
      .modules-left > widget > *,
      .modules-center > widget > *,
      .modules-right > widget > * {
        background: #${c.overlay};
        color: #${c.rose};
        border-radius: 10px;
        padding: 2px 12px;
        margin: 0 3px;
      }
      #workspaces {
        padding: 0 4px;
      }
      #workspaces button {
        color: #${c.subtle};
        padding: 0 6px;
        border-radius: 8px;
      }
      #workspaces button.active {
        background: #${c.pine};
        color: #${c.foam};
      }
      #workspaces button:hover {
        background: #${c.love};
        color: #${c.gold};
      }
      #clock {
        color: #${c.iris};
      }
    '';
  };

  programs.rofi = {
    enable = true;
    settings = {
      terminal = "ghostty";
      font = "BlexMono Nerd Font 12";
      show-icons = true;
      icon-theme = "Tela-circle-pink";
      display-drun = " ";
      display-window = " ";
    };
    theme =
      let
        l = config.lib.formats.rasi.mkLiteral;
      in
      {
        "*" = {
          bg = l "#${c.base}e6";
          bg-alt = l "#${c.overlay}";
          fg = l "#${c.text}";
          accent = l "#${c.love}";
          background-color = l "transparent";
          text-color = l "@fg";
        };
        window = {
          width = l "36%";
          background-color = l "@bg";
          border = l "2px";
          border-color = l "@accent";
          border-radius = l "12px";
          padding = l "16px";
        };
        inputbar = {
          background-color = l "@bg-alt";
          border-radius = l "8px";
          padding = l "8px 12px";
          children = map l [
            "prompt"
            "entry"
          ];
        };
        prompt.text-color = l "#${c.iris}";
        listview = {
          lines = 8;
          spacing = l "4px";
          margin = l "12px 0 0 0";
        };
        element = {
          padding = l "6px 10px";
          border-radius = l "8px";
        };
        "element selected" = {
          background-color = l "#${c.pine}";
          text-color = l "#${c.foam}";
        };
        element-icon.size = l "1.2em";
        element-text.text-color = l "inherit";
      };
  };

  services.dunst = {
    enable = true;
    settings = {
      global = {
        font = "BlexMono Nerd Font 11";
        corner_radius = 10;
        frame_width = 2;
        frame_color = "#${c.iris}";
        background = "#${c.base}";
        foreground = "#${c.text}";
        offset = "(12, 12)";
        gap_size = 6;
      };
      urgency_critical.frame_color = "#${c.love}";
    };
  };

  programs.hyprlock = {
    enable = true;
    settings = {
      general.hide_cursor = true;
      background = [
        {
          path = "${wallpaper}";
          blur_passes = 3;
          blur_size = 6;
        }
      ];
      label = [
        {
          text = "$TIME";
          font_size = 72;
          color = "rgb(${c.rose})";
          position = "0, 160";
          halign = "center";
          valign = "center";
        }
      ];
      input-field = [
        {
          size = "280, 50";
          position = "0, -40";
          outline_thickness = 2;
          outer_color = "rgb(${c.iris})";
          inner_color = "rgb(${c.overlay})";
          font_color = "rgb(${c.text})";
          check_color = "rgb(${c.foam})";
          fail_color = "rgb(${c.love})";
          placeholder_text = "Password";
          rounding = 10;
        }
      ];
    };
  };

  services.hypridle = {
    enable = true;
    settings = {
      general = {
        lock_cmd = "pidof hyprlock || hyprlock";
        before_sleep_cmd = "loginctl lock-session";
        after_sleep_cmd = "hyprctl dispatch dpms on";
      };
      listener = [
        {
          timeout = 600;
          on-timeout = "loginctl lock-session";
        }
        {
          timeout = 900;
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };

  programs.wlogout = {
    enable = true;
    style = ''
      * {
        font-family: "BlexMono Nerd Font";
      }
      window {
        background-color: rgba(25, 23, 36, 0.85);
      }
      button {
        color: #${c.text};
        background-color: #${c.overlay};
        border: 2px solid #${c.overlay};
        border-radius: 12px;
        margin: 8px;
        background-repeat: no-repeat;
        background-position: center;
        background-size: 25%;
      }
      button:focus,
      button:hover {
        background-color: #${c.pine};
        border-color: #${c.love};
      }
    ''
    # 既定style.cssのアイコン指定を再定義
    + pkgs.lib.concatMapStrings
      (n: ''
        #${n} {
          background-image: image(url("${pkgs.wlogout}/share/wlogout/icons/${n}.png"));
        }
      '')
      [
        "lock"
        "logout"
        "suspend"
        "hibernate"
        "shutdown"
        "reboot"
      ];
  };
}

