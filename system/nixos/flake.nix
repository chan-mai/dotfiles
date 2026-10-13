{
  description = "dotfiles nixos configuration";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    agents-nix = {
      url = "github:sudosubin/agents.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, agents-nix }: {
    nixosConfigurations.kumo = nixpkgs.lib.nixosSystem {
      modules = [
        ../../modules/common.nix
        ./_common/nixos.nix
        ./_common/desktop.nix
        ./kumo/hosts.nix
        ./kumo/hardware-configuration.nix
        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "before-home-manager";
          home-manager.extraSpecialArgs = { inherit agents-nix; };
          home-manager.users.mq1 = import ./_common/home.nix;
        }
      ];
    };
  };
}
