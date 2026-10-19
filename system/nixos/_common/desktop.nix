{ pkgs, ... }:

{
  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };
  services.desktopManager.plasma6.enable = true;

  services.displayManager.sddm = {
    enable = true;
    wayland.enable = true;
  };

  security.pam.services.hyprlock = { };
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.sddm.enableGnomeKeyring = true;
  services.gvfs.enable = true;
  services.udisks2.enable = true;

  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  environment.systemPackages = with pkgs; [
    kdePackages.dolphin
    kde-rounded-corners
    pavucontrol
  ];

  fonts.packages = [ pkgs.lucide ];
}
