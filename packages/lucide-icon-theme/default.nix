{
  lib,
  fetchurl,
  runCommand,
  python3,
  # ColorScheme-Text既定色
  textColor ? "#4d3442",
  inherits ? [
    "Tela-circle-pink"
    "breeze"
    "hicolor"
  ],
}:

let
  version = "0.563.0";
  src = fetchurl {
    url = "https://registry.npmjs.org/lucide-static/-/lucide-static-${version}.tgz";
    hash = "sha256-7pl9WqhrEzQhVqVKRQrbl685EwRjQApirHF309uLjLQ=";
  };

  # コンテキスト → { freedesktop名 = Lucide名; }
  icons = {
    apps = {
      start-here = "cat";
      start-here-kde = "cat";
      start-here-kde-plasma = "cat";
      application-menu = "cat";
    };
    status = {
      audio-volume-high = "volume-2";
      audio-volume-high-danger = "volume-2";
      audio-volume-medium = "volume-2";
      audio-volume-low = "volume-1";
      audio-volume-muted = "volume-x";
      audio-input-microphone = "mic";
      audio-input-microphone-muted = "mic-off";
      microphone-sensitivity-high = "mic";
      microphone-sensitivity-medium = "mic";
      microphone-sensitivity-low = "mic";
      microphone-sensitivity-muted = "mic-off";
      network-wireless = "wifi";
      network-wireless-connected = "wifi";
      network-wireless-signal-excellent = "wifi";
      network-wireless-signal-good = "wifi";
      network-wireless-signal-ok = "wifi-high";
      network-wireless-signal-low = "wifi-low";
      network-wireless-signal-weak = "wifi-low";
      network-wireless-signal-none = "wifi-zero";
      network-wireless-100 = "wifi";
      network-wireless-80 = "wifi";
      network-wireless-60 = "wifi-high";
      network-wireless-40 = "wifi-low";
      network-wireless-20 = "wifi-low";
      network-wireless-0 = "wifi-zero";
      network-wireless-disconnected = "wifi-off";
      network-wireless-offline = "wifi-off";
      network-wired = "ethernet-port";
      network-wired-activated = "ethernet-port";
      network-connect = "ethernet-port";
      network-wired-disconnected = "unplug";
      network-disconnect = "unplug";
      network-offline = "unplug";
      bluetooth = "bluetooth";
      bluetooth-active = "bluetooth";
      bluetooth-online = "bluetooth";
      bluetooth-paired = "bluetooth-connected";
      bluetooth-disabled = "bluetooth-off";
      bluetooth-offline = "bluetooth-off";
      notifications = "bell";
      notification-inactive = "bell";
      notification-active = "bell-dot";
      notification-new = "bell-dot";
      notifications-disabled = "bell-off";
      preferences-desktop-notification-bell = "bell";
      klipper = "clipboard";
      dialog-information = "info";
      dialog-warning = "triangle-alert";
      dialog-error = "circle-x";
      battery = "battery";
    };
    actions = {
      system-shutdown = "power";
      system-reboot = "rotate-cw";
      system-log-out = "log-out";
      system-lock-screen = "lock";
      system-suspend = "moon";
      system-search = "search";
      search = "search";
      edit-find = "search";
      view-more = "ellipsis";
      overflow-menu = "ellipsis";
      open-menu = "menu";
      go-up = "chevron-up";
      go-down = "chevron-down";
      go-next = "chevron-right";
      go-previous = "chevron-left";
      go-home = "house";
      window-close = "x";
      window-minimize = "minus";
      window-maximize = "maximize-2";
      window-restore = "minimize-2";
      window-pin = "pin";
      window-new = "app-window";
      list-add = "plus";
      list-remove = "minus";
      edit-delete = "trash-2";
      edit-copy = "copy";
      edit-cut = "scissors";
      edit-paste = "clipboard";
      edit-undo = "undo-2";
      edit-redo = "redo-2";
      edit-rename = "pencil";
      document-edit = "pencil";
      document-save = "save";
      document-new = "file-plus";
      document-open = "folder-open";
      document-open-recent = "history";
      document-properties = "info";
      document-print = "printer";
      document-share = "share-2";
      folder-new = "folder-plus";
      configure = "settings";
      settings-configure = "settings";
      view-refresh = "refresh-cw";
      view-list-details = "list";
      view-list-icons = "layout-grid";
      view-preview = "eye";
      view-hidden = "eye-off";
      view-filter = "funnel";
      help-about = "info";
      dialog-ok = "check";
      dialog-ok-apply = "check";
      dialog-cancel = "x";
      media-playback-start = "play";
      media-playback-pause = "pause";
      media-playback-stop = "square";
      media-skip-forward = "skip-forward";
      media-skip-backward = "skip-back";
      bookmarks = "bookmark";
      bookmark-new = "bookmark";
      tag = "tag";
      mail-message = "mail";
      emblem-favorite = "heart";
      favorites = "heart";
      zoom-in = "zoom-in";
      zoom-out = "zoom-out";
      link = "link";
      external-link = "external-link";
      upload-media = "upload";
      download = "download";
      arrow-left = "arrow-left";
      arrow-right = "arrow-right";
      arrow-up = "arrow-up";
      arrow-down = "arrow-down";
      preferences-system = "settings";
      preferences-other = "sliders-horizontal";
      brightness-high = "sun";
    };
    places = {
      folder = "folder";
      inode-directory = "folder";
      folder-open = "folder-open";
      user-home = "house";
      folder-home = "house";
      user-desktop = "monitor";
      folder-documents = "file-text";
      folder-download = "download";
      folder-downloads = "download";
      folder-music = "music";
      folder-pictures = "image";
      folder-image = "image";
      folder-videos = "clapperboard";
      folder-video = "clapperboard";
      folder-cloud = "cloud";
      folder-recent = "history";
      folder-templates = "layout-template";
      folder-public = "users";
      user-trash = "trash-2";
      user-trash-full = "trash";
      network-workgroup = "network";
      folder-network = "network";
      user-identity = "user";
    };
    devices = {
      computer = "monitor";
      video-display = "monitor";
      drive-harddisk = "hard-drive";
      drive-removable-media = "usb";
      drive-removable-media-usb = "usb";
      media-optical = "disc";
      printer = "printer";
      camera-photo = "camera";
      input-keyboard = "keyboard";
      input-mouse = "mouse";
      input-gaming = "gamepad-2";
      audio-headphones = "headphones";
      audio-speakers = "speaker";
      cpu = "cpu";
      memory = "memory-stick";
    };
  };

  mapping = builtins.toFile "lucide-icon-map.json" (builtins.toJSON icons);
in
runCommand "lucide-icon-theme-${version}"
  {
    inherit src;
    nativeBuildInputs = [ python3 ];
    meta = {
      description = "Lucide based KDE icon theme";
      homepage = "https://lucide.dev/";
      license = lib.licenses.isc;
    };
  }
  ''
    tar -xzf $src
    dir=$out/share/icons/Lucide
    python3 - ${mapping} package/icons $dir ${lib.escapeShellArg textColor} <<'EOF'
    import json, os, re, sys
    mapping, srcdir, outdir, color = sys.argv[1:]
    missing = []
    for ctx, names in json.load(open(mapping)).items():
        os.makedirs(f"{outdir}/scalable/{ctx}", exist_ok=True)
        for name, lucide in names.items():
            path = f"{srcdir}/{lucide}.svg"
            if not os.path.exists(path):
                missing.append(lucide)
                continue
            body = re.search(r"<svg[^>]*>(.*)</svg>", open(path).read(), re.S).group(1)
            # Plasma配色追従用stylesheet
            svg = (
                '<svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24">'
                f'<style type="text/css" id="current-color-scheme">.ColorScheme-Text{{color:{color};}}</style>'
                '<g class="ColorScheme-Text" fill="none" stroke="currentColor" stroke-width="2"'
                ' stroke-linecap="round" stroke-linejoin="round">'
                f"{body}</g></svg>\n"
            )
            for n in (name, f"{name}-symbolic"):
                with open(f"{outdir}/scalable/{ctx}/{n}.svg", "w") as f:
                    f.write(svg)
    if missing:
        sys.exit(f"missing lucide icons: {sorted(set(missing))}")
    contexts = {"apps": "Applications", "status": "Status", "actions": "Actions", "places": "Places", "devices": "Devices"}
    with open(f"{outdir}/index.theme", "w") as f:
        dirs = [f"scalable/{c}" for c in contexts]
        f.write("[Icon Theme]\nName=Lucide\nComment=Lucide based icon theme\n")
        f.write("Inherits=${lib.concatStringsSep "," inherits}\n")
        f.write(f"Directories={','.join(dirs)}\n")
        for c, label in contexts.items():
            f.write(f"\n[scalable/{c}]\nSize=24\nMinSize=8\nMaxSize=512\nType=Scalable\nContext={label}\n")
    EOF
  ''
