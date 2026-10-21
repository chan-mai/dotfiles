{
  agents-nix,
  lib,
  pkgs,
  ...
}:

let
  github = agents-nix.agent-skills.${pkgs.stdenv.hostPlatform.system}.github;
  skills =
    github.everyinc.compound-engineering-plugin
    // {
      inherit (github.mattpocock.skills)
        code-review
        diagnosing-bugs
        domain-modeling
        git-guardrails-claude-code
        grill-me
        grill-with-docs
        grilling
        handoff
        improve-codebase-architecture
        migrate-to-shoehorn
        prototype
        scaffold-exercises
        setup-matt-pocock-skills
        setup-pre-commit
        tdd
        teach
        to-spec
        to-tickets
        triage
        writing-beats
        writing-for-agents
        writing-fragments
        writing-shape
        ;
      inherit (github.cloudflare.skills)
        agents-sdk
        cloudflare
        cloudflare-email-service
        cloudflare-one
        cloudflare-one-migrations
        durable-objects
        sandbox-migrate-to-next
        sandbox-next
        sandbox-stable
        turnstile-spin
        web-perf
        workers-best-practices
        wrangler
        ;
      inherit (github.vuejs-ai.skills)
        create-adaptable-composable
        vue-best-practices
        vue-debug-guides
        vue-jsx-best-practices
        vue-options-api-best-practices
        vue-pinia-best-practices
        vue-router-best-practices
        vue-testing-best-practices
        ;
      inherit (github.herdrdev.herdr) herdr;
      inherit (github.vercel-labs.skills) find-skills;
      inherit (github.nanaism.yomiyasu) yomiyasu;
      inherit (github.ikora128.stop-ai-slop-jp) stop-ai-slop-jp;
      inherit (github.marycache.imozuru) imozuru;
    };
in
{
  # ~/.claude/skillsは~/.agents/skillsリンク, synced/はCC管理
  home.file = lib.mapAttrs' (
    name: src: lib.nameValuePair ".agents/skills/${name}" { source = src; }
  ) skills;
}
