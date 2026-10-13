{
  lib,
  # dotfiles-assets(private)
  src,
  runCommand,
  python3,
  win2xcur,
}:

let
  # Windowsカーソル名 → XCursor名, 別名
  cursors = {
    "通常" = [ "left_ptr" "default" "arrow" "top_left_arrow" ];
    "テキスト" = [ "xterm" "text" "ibeam" ];
    "リンク" = [ "hand2" "pointer" "hand1" "pointing_hand" "grab" "grabbing" "openhand" ];
    "待ち" = [ "watch" "wait" ];
    "作業中" = [ "left_ptr_watch" "progress" "half-busy" ];
    "移動" = [ "fleur" "move" "all-scroll" "size_all" ];
    "領域" = [ "crosshair" "cross" "tcross" "cell" ];
    "上下" = [ "sb_v_double_arrow" "ns-resize" "n-resize" "s-resize" "row-resize" "size_ver" "v_double_arrow" "top_side" "bottom_side" ];
    "左右" = [ "sb_h_double_arrow" "ew-resize" "e-resize" "w-resize" "col-resize" "size_hor" "h_double_arrow" "left_side" "right_side" ];
    "斜め1" = [ "bd_double_arrow" "nwse-resize" "nw-resize" "se-resize" "size_fdiag" "top_left_corner" "bottom_right_corner" ];
    "斜め2" = [ "fd_double_arrow" "nesw-resize" "ne-resize" "sw-resize" "size_bdiag" "top_right_corner" "bottom_left_corner" ];
    "不可" = [ "not-allowed" "crossed_circle" "no-drop" "forbidden" "circle" ];
  };
  mapping = builtins.toFile "hachiware-cursor-map.json" (builtins.toJSON cursors);
in
runCommand "hachiware-cursor"
  {
    inherit src;
    nativeBuildInputs = [
      python3
      win2xcur
    ];
    meta = {
      description = "Animated Hachiware mouse cursor converted to XCursor";
      homepage = "https://booth.pm/ja/items/5566467";
      license = lib.licenses.unfree;
    };
  }
  ''
    mkdir ani
    # SJISファイル名をASCII展開
    python3 - ${mapping} <<'EOF'
    import json, sys, zipfile, os
    mapping = json.load(open(sys.argv[1]))
    with zipfile.ZipFile(os.environ["src"]) as z:
        for info in z.infolist():
            name = info.filename.encode("cp437").decode("cp932")
            stem = os.path.splitext(os.path.basename(name))[0]
            if stem in mapping:
                with open(f"ani/{mapping[stem][0]}.ani", "wb") as f:
                    f.write(z.read(info))
    missing = [k for k, v in mapping.items() if not os.path.exists(f"ani/{v[0]}.ani")]
    if missing:
        sys.exit(f"missing cursors: {missing}")
    EOF

    dir=$out/share/icons/Hachiware
    mkdir -p $dir/cursors
    win2xcur ani/*.ani -o $dir/cursors
    cd $dir/cursors
    ${lib.concatStringsSep "\n" (
      lib.concatMap (
        names: map (alias: "ln -s ${builtins.head names} ${alias}") (builtins.tail names)
      ) (builtins.attrValues cursors)
    )}
    cat > $dir/index.theme <<EOF
    [Icon Theme]
    Name=Hachiware
    Comment=Animated Hachiware cursor
    EOF
  ''
