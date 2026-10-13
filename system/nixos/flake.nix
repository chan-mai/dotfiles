{
  description = "dotfiles nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    dotfiles-assets = {
      url = "github:chan-mai/dotfiles-assets";
      flake = false;
    };
    agents-nix = {
      url = "github:sudosubin/agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, disko, dotfiles-assets, agents-nix }: {
    nixosConfigurations.kumo = nixpkgs.lib.nixosSystem {
      modules = [
        ../../modules/common.nix
        ./_common/nixos.nix
        ./_common/desktop.nix
        ./kumo/hosts.nix
        ./kumo/hardware-configuration.nix
        disko.nixosModules.disko
        ./kumo/disko.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "before-home-manager";
          home-manager.extraSpecialArgs = { inherit agents-nix dotfiles-assets; };
          home-manager.users.mq1 = import ./_common/home.nix;
        }
      ];
    };
  };
}
