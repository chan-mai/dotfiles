{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  nixpkgs.overlays = [ (import ../../../packages) ];

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [ "@wheel" ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  zramSwap.enable = true;

  networking.networkmanager.enable = true;

  time.timeZone = "Asia/Tokyo";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.supportedLocales = [
    "en_US.UTF-8/UTF-8"
    "ja_JP.UTF-8/UTF-8"
  ];
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5 = {
      waylandFrontend = true;
      addons = with pkgs; [
        fcitx5-mozc
        fcitx5-rose-pine
      ];
      settings.addons.classicui.globalSection.Theme = "rose-pine";
    };
  };

  users.users.mq1 = {
    isNormalUser = true;
    shell = pkgs.zsh;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "docker"
    ];
  };
  programs.zsh.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  hardware.bluetooth.enable = true;
  services.openssh.enable = true;
  services.tailscale.enable = true;

  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    # ブラウザ連携, システム認証
    polkitPolicyOwners = [ "mq1" ];
  };

  environment.systemPackages = with pkgs; [
    git
    ghostty
    wl-clipboard
  ];
}
