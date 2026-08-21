{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    ansible
    argocd
    awscli2
    btop
    cmake
    dotslash
    fastfetch
    ffmpeg
    gh
    go
    go-task
    (google-cloud-sdk.withExtraComponents (with google-cloud-sdk.components; [
      beta
      config-connector
    ]))
    herdr
    just
    k3d
    kubectl
    kubelogin-oidc
    kubernetes-helm
    mkcert
    mysql84
    nodejs_22
    osv-scanner
    oxipng
    pnpm
    poppler-utils
    postgresql
    rdap
    ripgrep
    rustup
    sshpass
    ssm-session-manager-plugin
    terraform
    uv
    wasm-pack
    # curl-cffi 0.15はdarwinビルド不可, unstable到達後に除外解除
    (yt-dlp.overridePythonAttrs (old: {
      dependencies = builtins.filter (d: (d.pname or "") != "curl-cffi") old.dependencies;
    }))
    zsh-autosuggestions
    # GUI
    bitwarden-desktop
    dbeaver-bin
    google-chrome
    vscode
    wireshark
  ];

  fonts.packages = with pkgs; [
    fira-code
    nerd-fonts.blex-mono
    noto-fonts-cjk-sans
    source-han-code-jp
  ];
}
