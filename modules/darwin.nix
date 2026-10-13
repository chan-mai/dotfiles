{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # GUI
    ghostty-bin
    maccy
    scroll-reverser
    tailscale-gui
    vlc-bin
  ];
}
