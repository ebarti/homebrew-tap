class Skills < Formula
  desc "Agent skills distilled from technical books, for Claude/Codex/Gemini/Antigravity"
  homepage "https://github.com/ebarti/skills"
  url "https://github.com/ebarti/skills/archive/refs/tags/v1.0.1.tar.gz"
  sha256 "66b054ad2c58492f4a7550e58dbb7a3665e0ca47fbd5bbfdee527cb4d407f30a"
  license "MIT"

  def install
    # Keep the skill folders + installer at a stable Homebrew path; `brew upgrade`
    # refreshes them in place so every symlinked agent picks up new content.
    libexec.install Dir["*"]

    (bin/"ebarti-skills").write <<~SH
      #!/bin/bash
      # Thin wrapper: run the bundled installer against the Homebrew-managed
      # skills source (no git clone needed).
      exec /bin/bash "#{opt_libexec}/install.sh" --source "#{opt_libexec}" "$@"
    SH
    chmod 0755, bin/"ebarti-skills"
  end

  def caveats
    <<~EOS
      Install the skills into your agents with:

        ebarti-skills            # interactive picker
        ebarti-skills --all      # Claude, Codex, Gemini, and Antigravity
        ebarti-skills --help     # all flags (--targets, --project, --dry-run, ...)

      Skills are symlinked from the Homebrew prefix, so:

        brew upgrade skills

      refreshes every installed agent in place — no re-linking required.
    EOS
  end

  test do
    assert_match "ai-rag-and-agents", shell_output("#{bin}/ebarti-skills --list")
  end
end
