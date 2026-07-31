#!/usr/bin/env bash
# 新電腦一鍵建立工作環境
#   - 安裝 Homebrew / Xcode CLT
#   - 安裝 nvim 及其相關套件 (LSP / formatter / debugger / treesitter)
#   - 安裝 GUI app: cmux, dbeaver, redis insight, postman, dia, docker
#   - 建立 .short.sh 的 shell alias
#
# 用法:  sh init.sh
# 這個 script 可以重複執行 (idempotent)，已安裝的會自動略過。

set -u

# ---------------------------------------------------------------------------
# 小工具
# ---------------------------------------------------------------------------
info()  { printf "\033[1;34m==>\033[0m %s\n" "$*"; }
warn()  { printf "\033[1;33m[skip]\033[0m %s\n" "$*"; }

# 安裝 brew formula (若尚未安裝)
brew_install() {
  for pkg in "$@"; do
    if brew list --formula "$pkg" >/dev/null 2>&1; then
      warn "formula $pkg 已安裝"
    else
      info "安裝 formula $pkg"
      brew install "$pkg"
    fi
  done
}

# 安裝 brew cask (若尚未安裝)
cask_install() {
  for pkg in "$@"; do
    if brew list --cask "$pkg" >/dev/null 2>&1; then
      warn "cask $pkg 已安裝"
    else
      info "安裝 cask $pkg"
      brew install --cask "$pkg"
    fi
  done
}

# 安裝 npm global 套件 (若尚未安裝)
npm_install() {
  for pkg in "$@"; do
    if npm ls -g --depth 0 "$pkg" >/dev/null 2>&1; then
      warn "npm -g $pkg 已安裝"
    else
      info "安裝 npm -g $pkg"
      npm install -g "$pkg"
    fi
  done
}

# ---------------------------------------------------------------------------
# 1. Xcode Command Line Tools (treesitter 編譯、git 等會用到)
# ---------------------------------------------------------------------------
if ! xcode-select -p >/dev/null 2>&1; then
  info "安裝 Xcode Command Line Tools (請依 GUI 視窗完成安裝後再重跑本 script)"
  xcode-select --install || true
else
  warn "Xcode Command Line Tools 已安裝"
fi

# ---------------------------------------------------------------------------
# 2. Homebrew
# ---------------------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  info "安裝 Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # 讓當前 shell 立即找得到 brew (Apple Silicon 路徑)
  if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
else
  warn "Homebrew 已安裝"
fi

# ---------------------------------------------------------------------------
# 3. 語言 runtime 與 CLI 工具
# ---------------------------------------------------------------------------
info "安裝語言 runtime 與 CLI 工具"
brew_install \
  neovim \
  node \
  go \
  python \
  openjdk@21 \
  git \
  gh \
  tmux \
  lazygit \
  gotestsum \
  ripgrep \
  fd \
  fzf \
  tree-sitter

# ---------------------------------------------------------------------------
# 4. nvim LSP / formatter / debugger
# ---------------------------------------------------------------------------
info "安裝 nvim LSP / formatter / debugger"
brew_install \
  lua-language-server \
  stylua \
  gopls \
  delve \
  jdtls

# 需要 node 的 LSP (透過 npm 安裝)
info "安裝 node 系 LSP"
npm_install \
  pyright \
  typescript \
  typescript-language-server \
  vscode-langservers-extracted

# Claude Code (cc 函式 / claudecode.nvim 會用到)
npm_install @anthropic-ai/claude-code

# ---------------------------------------------------------------------------
# 5. 字型 (NvChad 需要 Nerd Font)
# ---------------------------------------------------------------------------
cask_install font-jetbrains-mono-nerd-font

# ---------------------------------------------------------------------------
# 6. GUI 應用程式
# ---------------------------------------------------------------------------
info "安裝 GUI app"
cask_install \
  cmux \
  dbeaver-community \
  redis-insight \
  postman \
  docker-desktop

# Dia 瀏覽器 (The Browser Company) 目前沒有 Homebrew cask，需手動下載
if [ -d "/Applications/Dia.app" ]; then
  warn "Dia 已安裝"
else
  info "Dia 沒有 Homebrew 版本，開啟官網手動下載: https://www.diabrowser.com/"
  open "https://www.diabrowser.com/download" 2>/dev/null || true
fi

# ---------------------------------------------------------------------------
# 7. shell alias (.short.sh)
# ---------------------------------------------------------------------------
info "設定 shell alias"
ln -sf ~/.config/nvim/.short.sh ~/.short.sh
grep -qxF 'source ~/.short.sh' ~/.zshrc || echo 'source ~/.short.sh' >> ~/.zshrc

info "完成！開啟 nvim 讓 lazy.nvim 自動安裝 plugin，並執行 :TSUpdate。"
