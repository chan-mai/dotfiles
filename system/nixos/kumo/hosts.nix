{ config, pkgs, ... }:

{
  networking.hostName = "kumo";

  boot.kernelPackages = pkgs.linuxPackages_latest;
  # Apple VIDのCX製キーボード, F1-F12優先
  boot.extraModprobeConfig = "options hid_apple fnmode=2";

  # RTX 5070, Blackwellだとopenカーネルモジュール必須らしい？
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    open = true;
    modesetting.enable = true;
    powerManagement.enable = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };
  environment.sessionVariables = {
    LIBVA_DRIVER_NAME = "nvidia";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NVD_BACKEND = "direct";
  };

  # ゲーム系
  programs.steam.enable = true;
  programs.gamemode.enable = true;
  programs.gamescope.enable = true;

  # GPU推論
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
  };
  virtualisation.docker.enable = true;
  hardware.nvidia-container-toolkit.enable = true;

  environment.systemPackages = with pkgs; [
    mangohud
    nvtopPackages.nvidia
    prismlauncher
    winboat
    # VRC関連
    alcom
    unityhub
  ];

  # VCC推奨でpinning
  home-manager.users.mq1.systemd.user.services.unity-editor-install =
    let
      version = "2022.3.22f1";
      changeset = "887be4894c44";
    in
    {
      Unit = {
        Description = "Install Unity ${version} via Unity Hub";
        ConditionPathExists = "!%h/Unity/Hub/Editor/${version}";
        After = [ "network-online.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.unityhub}/bin/unityhub -- --headless install --version ${version} --changeset ${changeset} --module windows-mono";
      };
      Install.WantedBy = [ "default.target" ];
    };

  system.stateVersion = "26.11";
}
