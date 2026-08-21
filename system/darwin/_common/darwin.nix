{ ... }:

{
  # terraform用(BUSL)
  nixpkgs.config.allowUnfree = true;

  users.users.mq1.home = "/Users/mq1";

  # Nix本体はDeterminate Nixが管理
  nix.enable = false;

  # sudoのTouch ID認証
  security.pam.services.sudo_local.touchIdAuth = true;

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
