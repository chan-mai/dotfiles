let
  # システム: NVMe 512GB, データ: SATA SSD 1TB
  systemDevice = "/dev/disk/by-id/nvme-SPCC_M.2_PCIe_SSD_1BMW3X5QTW6GP2DE9DMV";
  dataDevice = "/dev/disk/by-id/ata-CT1000BX500SSD1_2507E9A72F55";
  btrfsOptions = [
    "compress=zstd"
    "noatime"
  ];
in
{
  disko.devices.disk = {
    main = {
      type = "disk";
      device = systemDevice;
      content = {
        type = "gpt";
        partitions = {
          ESP = {
            size = "1G";
            type = "EF00";
            content = {
              type = "filesystem";
              format = "vfat";
              mountpoint = "/boot";
              mountOptions = [ "umask=0077" ];
            };
          };
          luks = {
            size = "100%";
            content = {
              type = "luks";
              name = "cryptroot";
              # パスフレーズはdisko実行時に対話入力
              settings.allowDiscards = true;
              content = {
                type = "btrfs";
                extraArgs = [ "-f" ];
                subvolumes = {
                  "@root" = {
                    mountpoint = "/";
                    mountOptions = btrfsOptions;
                  };
                  "@home" = {
                    mountpoint = "/home";
                    mountOptions = btrfsOptions;
                  };
                  "@nix" = {
                    mountpoint = "/nix";
                    mountOptions = btrfsOptions;
                  };
                };
              };
            };
          };
        };
      };
    };

    data = {
      type = "disk";
      device = dataDevice;
      content = {
        type = "gpt";
        partitions.luks = {
          size = "100%";
          content = {
            type = "luks";
            name = "cryptdata";
            settings.allowDiscards = true;
            content = {
              type = "btrfs";
              extraArgs = [ "-f" ];
              subvolumes."@data" = {
                mountpoint = "/data";
                mountOptions = btrfsOptions;
              };
            };
          };
        };
      };
    };
  };
}
