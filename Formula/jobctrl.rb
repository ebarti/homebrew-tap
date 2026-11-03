# frozen_string_literal: true

# This template is rendered only from a P6-verified signed stable descriptor.
# It intentionally has no HEAD/source-build path and no developer toolchain
# dependencies. The ZIP is the same immutable payload resolved by curl.
require "open3"
require "json"

class Jobctrl < Formula
  desc "Local-first job search mission control: discover, score, tailor, apply"
  homepage "https://jobctrl.dev"

  url "https://releases.jobctrl.dev/v1/artifacts/0.4.3-12ce82512e025bbc5b38ba1c930d508a1fa62b23-darwin-arm64/jobctrl-0.4.3-darwin-arm64.zip"
  version "0.4.3"
  sha256 "ee4591d6dd0c276ad1abb0824e1de8d0d4409a3a7a4080737dcb1a8ffec5392d"
  license "AGPL-3.0-only"
  version_scheme 2

  JOBCTRL_BUILD_ID = "0.4.3-12ce82512e025bbc5b38ba1c930d508a1fa62b23-darwin-arm64"
  JOBCTRL_MANIFEST_SHA256 = "f968f0515dd4306b597ada2be2ea67dea12e4562783c8035877671534606292b"
  JOBCTRL_DESCRIPTOR_URL = "https://releases.jobctrl.dev/v1/artifacts/0.4.3-12ce82512e025bbc5b38ba1c930d508a1fa62b23-darwin-arm64/release-descriptor.json"
  JOBCTRL_DESCRIPTOR_SHA256 = "a2ce015a011961b087bd2d61ccd32c442ed67b38fd12e1b74539473a22a56957"
  JOBCTRL_SIGNATURE_SHA256 = "4bd69b0631eac7ff24aac76534fb9e49fa772ba74d0ff40401c35d3fccb4b561"
  DEVELOPER_ID_REQUIREMENT = "anchor apple generic " \
                             "and certificate 1[field.1.2.840.113635.100.6.2.6] exists " \
                             "and certificate leaf[field.1.2.840.113635.100.6.1.13] exists"

  resource "jobctrl-release-descriptor" do
    url JOBCTRL_DESCRIPTOR_URL
    sha256 JOBCTRL_DESCRIPTOR_SHA256
  end

  resource "jobctrl-release-descriptor-signature" do
    url "#{JOBCTRL_DESCRIPTOR_URL}.sig"
    sha256 JOBCTRL_SIGNATURE_SHA256
  end

  def verify_developer_id_executable!(executable)
    codesign_output, codesign_status = Open3.capture2e(
      "/usr/bin/codesign",
      "--verify",
      "--strict",
      "-R=#{DEVELOPER_ID_REQUIREMENT}",
      "--verbose=2",
      executable.to_s,
    )
    unless codesign_status.success?
      odie "JobCtrl Developer ID signature verification failed for #{executable}: #{codesign_output}"
    end
  end

  def managed_headless_shell
    candidates = Dir[(buildpath/"chromium").join("**", "chrome-headless-shell")]
    candidates.select! { |candidate| File.file?(candidate) && File.executable?(candidate) }
    odie "JobCtrl release has no managed Chromium headless shell to verify" if candidates.length != 1
    Pathname.new(candidates.first)
  end

  def install
    # Formula installation remains entirely prefix-owned. The executable in
    # libexec/bootstrap is a native bootstrap, not the runtime selector: on its first
    # normal-user invocation it authenticates these resources into the user
    # store, then re-execs that stable selector.
    # Apple's live notarization service is unavailable in Homebrew's sandbox.
    # Require a strict Developer ID signature here; the normal-user bootstrap
    # checks notarization before running its installer, which verifies the full
    # payload before activation. Homebrew's sandbox remains unchanged.
    verify_developer_id_executable!(buildpath/"launcher/jobctrl")
    verify_developer_id_executable!(buildpath/"launcher/jobctrl-installer")
    verify_developer_id_executable!(managed_headless_shell)
    bootstrap = libexec/"bootstrap"
    bootstrap.install buildpath/"launcher/jobctrl"
    bootstrap.install buildpath/"launcher/jobctrl-installer"
    bootstrap.install cached_download => "jobctrl-release.zip"
    resource("jobctrl-release-descriptor").stage do
      bootstrap.install "release-descriptor.json" => "homebrew-release.json"
    end
    resource("jobctrl-release-descriptor-signature").stage do
      bootstrap.install "release-descriptor.json.sig" => "homebrew-release.json.sig"
    end
    (bootstrap/"homebrew-bootstrap.json").write(
      JSON.generate(
        {
          schemaVersion:    1,
          descriptorUrl:    JOBCTRL_DESCRIPTOR_URL,
          descriptor:       "homebrew-release.json",
          signature:        "homebrew-release.json.sig",
          archive:          "jobctrl-release.zip",
          buildId:          JOBCTRL_BUILD_ID,
          descriptorSha256: JOBCTRL_DESCRIPTOR_SHA256,
        },
      ),
    )
    bin.install_symlink bootstrap/"jobctrl"
  end

  def caveats
    upgrade_warning = if ["0.4.0", "0.4.1"].include?(version.to_s)
      <<~EOS
        Upgrades from normally used JobCtrl 0.3.1 workspaces are currently
        blocked because earlier child processes cannot be verified as stopped.
        The previous workspace and installation records are preserved. The
        new Homebrew command cannot start that workspace; keep the registry and
        databases intact and see https://jobctrl.dev/user/getting-started#update-roll-back-or-remove-jobctrl
      EOS
    end
    <<~EOS
      JobCtrl #{version} (#{JOBCTRL_BUILD_ID}) uses the same signed ZIP and
      manifest as the curl channel. It has no Homebrew dependencies and no
      source checkout. The verified ZIP privately bundles Node, Python,
      Temporal, and one managed core Chromium; Git, Corepack, uv, Poppler, and
      system Chrome are not required unless you explicitly enable an
      authenticated-browser capability.
      #{upgrade_warning}
    EOS
  end

  test do
    assert_path_exists libexec/"bootstrap"/"homebrew-bootstrap.json"
    assert_predicate bin/"jobctrl", :symlink?
  end
end
