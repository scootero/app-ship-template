# =============================================================================
# Homebrew cask — lets people run  brew install --cask <you>/tap/<app>   [mac] OPTIONAL
# =============================================================================
# Only for Mac apps distributed as a DMG (release-mac.yml). Homebrew reads
# casks from a separate "tap" repo named homebrew-tap, so to use this:
#   1. Create github.com/__GITHUB_USER__/homebrew-tap
#   2. Copy this file there as Casks/<app-name-lowercase>.rb
#   3. Bump `version` after each release (or automate it in release-mac.yml)
# Users then install with:  brew install --cask __GITHUB_USER__/tap/<name>
# =============================================================================
cask "__APP_NAME__" do
  version "0.1.0"
  sha256 :no_check   # skips checksum; fine for a personal tap

  url "https://github.com/__GITHUB_USER__/__APP_NAME__/releases/download/v#{version}/__APP_NAME__.dmg"
  name "__DISPLAY_NAME__"
  desc "TODO: one-line description"
  homepage "https://__GITHUB_USER__.github.io/__APP_NAME__/"

  depends_on macos: ">= :sonoma"   # match MACOS_MIN in ship.config

  app "__APP_NAME__.app"
end
