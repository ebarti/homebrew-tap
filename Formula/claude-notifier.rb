class ClaudeNotifier < Formula
  desc "Native macOS notifications with the Claude logo for Claude Code"
  homepage "https://github.com/ebarti/claude-notifier"
  url "https://github.com/ebarti/claude-notifier/releases/download/v1.1.0/claude-notifier-1.1.0-macos.tar.gz"
  sha256 "02281df7c179d689777638863ae890207120086058c85ce41997700dda20d3f8"
  license "MIT"

  depends_on :macos

  def install
    prefix.install "ClaudeNotifier.app"
    bin.install_symlink prefix/"ClaudeNotifier.app/Contents/MacOS/claude-notifier"
  end

  def post_install
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
