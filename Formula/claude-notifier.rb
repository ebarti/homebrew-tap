class ClaudeNotifier < Formula
  desc "Native macOS notifications with the Claude logo for Claude Code"
  homepage "https://github.com/ebarti/claude-notifier"
  url "https://github.com/ebarti/claude-notifier/releases/download/v1.1.0/claude-notifier-1.1.0-macos.tar.gz"
  sha256 "4417a166727cfdc5694648e7ac760f889775fd3476947e1a7637aafa4cf407a9"
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
