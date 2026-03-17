class ClaudeNotifier < Formula
  desc "Native macOS notifications with the Claude logo for Claude Code"
  homepage "https://github.com/ebarti/claude-notifier"
  url "https://github.com/ebarti/claude-notifier/archive/refs/tags/v1.0.0.tar.gz"
  sha256 "82a102538f7372f9ef8d8ac6399e12d10b9fde57455e3d0ecc872ac8977cb657"
  license "MIT"

  depends_on :macos

  def install
    system "make", "build"
    prefix.install "build/ClaudeNotifier.app"
    bin.install_symlink prefix/"ClaudeNotifier.app/Contents/MacOS/claude-notifier"
  end

  def post_install
    # Register with Launch Services so macOS picks up the icon
    system "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister",
           "-f", prefix/"ClaudeNotifier.app"
  end

  def caveats
    <<~EOS
      To use with Claude Code, add this to ~/.claude/settings.json:

        {
          "hooks": {
            "Notification": [
              {
                "matcher": "",
                "hooks": [
                  {
                    "type": "command",
                    "command": "claude-notifier"
                  }
                ]
              }
            ]
          }
        }

      On first run, macOS will ask for notification permission.
    EOS
  end

  test do
    assert_match "1.0.0", shell_output("#{bin}/claude-notifier -version").strip
    assert_match "Usage", shell_output("#{bin}/claude-notifier -help")
  end
end
