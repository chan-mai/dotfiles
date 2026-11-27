{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    # GUI
    ghostty-bin
    maccy
    scroll-reverser
    vlc-bin
  ];
}
