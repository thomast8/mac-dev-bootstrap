# mac-dev-bootstrap

Bootstrap framework for a Warp + Claude Code Mac, from a **bare machine** (no git, no Homebrew, no Xcode CLT) to a fully configured stack. This is the reusable, identity-free core; your personal data lives in a separate private orchestrator.

## One-liner

```sh
ORCH_REPO=you/your-orchestrator /bin/bash -c \
  "$(curl -fsSL https://raw.githubusercontent.com/<acct>/mac-dev-bootstrap/main/bare-mac.sh)"
```

`bare-mac.sh` installs Xcode Command Line Tools, Homebrew, and `gh`; prompts `gh auth login`; clones your private orchestrator; and hands off to its `setup`. Add a trailing `-- --with-work` to also apply the work layer. Idempotent.

## Architecture

A **private orchestrator** repo wires together this framework and several **public** content repos, layering identity in at setup time:

```
mac-dev-bootstrap (public)      this repo: bare-mac.sh, Brewfile, install-prereqs,
                                lib/render.sh, templated git/ + ssh/, manifest.example
warp-claude-workflow (public)   -> ~/.warp   (Warp config + worktree tabs)
claude-code-config   (public)   -> ~/.claude (generic Claude Code config)
shell-editor-dotfiles(public)   -> ~/.zshrc + ~/.config/zed
your-orchestrator    (private)  manifest (which public repos), profiles/personal +
                                profiles/work (values + overlay), setup [--with-work]
```

**Templating.** Public files carry `@@TOKEN@@` placeholders (`@@GH_USER@@`, `@@GIT_EMAIL@@`, `@@GIT_NAME@@`, `@@SIGNING_KEY@@`) rendered by `lib/render.sh` from `profiles/personal/values`. Identifiers only - never secrets or private keys.

**Profiles.** The default install is personal-only and fully self-contained. `setup --with-work` layers in *additive* work fragments (a `gitconfig-work` + `includeIf`, a `~/.config/zsh/work.zsh` org->account map, an extra MCP server, an appended CLAUDE.md section) so the work layer never lands where it isn't wanted.

## In this repo

- `bare-mac.sh` - the bootstrap entry point (run raw via curl; takes `ORCH_REPO`).
- `Brewfile` - formulae + casks (git, gh, node, uv, warp, zed, ...).
- `install-prereqs` - generic tooling: Homebrew, the Brewfile, oh-my-zsh + plugins, npm globals.
- `lib/render.sh` - the `@@TOKEN@@` substitution engine.
- `git/`, `ssh/` - templated `gitconfig`, global git `ignore`, and ssh `config`.
- `manifest.example`, `values.example` - copy these into your private orchestrator.

## Adopt it

Fork the four public repos, create a **private** orchestrator with a `manifest` (from `manifest.example`), `profiles/personal/values` (from `values.example`), any `profiles/*/overlay` fragments, and a `setup` that renders + lays everything down. Then run the one-liner.
