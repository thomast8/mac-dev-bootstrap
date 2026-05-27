# Brewfile - dev tools for the Warp-centric Claude Code stack.
# Install with: brew bundle --file=Brewfile

# --- taps ---
tap "withgraphite/tap"

# --- CLI tools ---
brew "git"
brew "gh"
brew "node"
brew "jq"
brew "fzf"               # PR-picker fallback in the worktree scripts
brew "ripgrep"
brew "age"               # encrypted SSH key bundle (decrypted during setup)
brew "withgraphite/tap/graphite" # gt (optional; plain-git-first workflow)
brew "lazygit"
brew "just"
brew "tmux"

# --- language/runtime baseline ---
brew "python@3.13"
brew "uv"                # Python package manager

# --- dev apps ---
cask "warp"              # primary terminal
cask "zed"               # primary editor
cask "claude"            # Claude desktop app
cask "superwhisper"      # dictation app
cask "docker-desktop"
