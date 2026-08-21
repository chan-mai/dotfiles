{ pkgs, ... }:

{
  # terraform用(BUSL)
  nixpkgs.config.allowUnfree = true;

  # darwin固有パッケージ
  environment.systemPackages = with pkgs; [
    (pkgs.callPackage ../../../packages/coderabbit-cli { })
    # GUI
    ghostty-bin
    maccy
    scroll-reverser
    slack
  ];

  users.users.mq1.home = "/Users/mq1";
  # system.defaultsの書き込み先ユーザー
  system.primaryUser = "mq1";

  # Nix本体はDeterminate Nixが管理
  nix.enable = false;

  # sudoのTouch ID認証
  security.pam.services.sudo_local.touchIdAuth = true;

  # nixpkgs側の改変で署名破損したアプリをad-hoc再署名
  system.activationScripts.postActivation.text = ''
    if [ -d "/Applications/Nix Apps/Scroll Reverser.app" ]; then
      /usr/bin/codesign --force --deep --sign - --preserve-metadata=entitlements \
        "/Applications/Nix Apps/Scroll Reverser.app" 2>/dev/null || true
    fi
  '';

  # Dock
  system.defaults.dock = {
    tilesize = 49;
    show-recents = false;
  };

  # Finder
  system.defaults.finder = {
    # リスト表示
    FXPreferredViewStyle = "Nlsv";
    ShowMountedServersOnDesktop = true;
  };

  # Global settings
  system.defaults.NSGlobalDomain = {
    AppleShowAllExtensions = true;
    # Fnキーを標準ファンクションキーとして使用
    "com.apple.keyboard.fnState" = true;
    # 軌跡の速さ
    "com.apple.trackpad.scaling" = 3.0;
  };

  # Trackpad
  system.defaults.trackpad = {
    # タップでクリック
    Clicking = true;
    TrackpadThreeFingerDrag = true;
  };

  # Wiresharkキャプチャ用/dev/bpf*権限設定(ChmodBPF相当)
  launchd.daemons.chmod-bpf = {
    script = ''
      FORCE_CREATE_BPF_MAX=256
      SYSCTL_MAX=$(/usr/sbin/sysctl -n debug.bpf_maxdevices)
      if [ "$FORCE_CREATE_BPF_MAX" -gt "$SYSCTL_MAX" ]; then
        FORCE_CREATE_BPF_MAX="$SYSCTL_MAX"
      fi
      CUR_DEV=0
      while [ "$CUR_DEV" -lt "$FORCE_CREATE_BPF_MAX" ]; do
        read -r -n 0 < "/dev/bpf$CUR_DEV" > /dev/null 2>&1
        CUR_DEV=$((CUR_DEV + 1))
      done
      /usr/bin/chgrp access_bpf /dev/bpf*
      /bin/chmod g+rw /dev/bpf*
    '';
    serviceConfig.RunAtLoad = true;
  };

  system.stateVersion = 6;
}
