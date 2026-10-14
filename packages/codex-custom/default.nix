{
  codex,
  prompt ? ./prompt.md,
}:

codex.overrideAttrs (old: {
  patches = (old.patches or [ ]) ++ [ ./custom-instructions.patch ];
  postPatch = (old.postPatch or "") + ''
    cp ${prompt} models-manager/prompt.md
    cp ${prompt} protocol/src/prompts/base_instructions/default.md
  '';
})
