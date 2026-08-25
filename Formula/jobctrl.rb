# frozen_string_literal: true

# This template is rendered only from a P6-verified signed stable descriptor.
# It intentionally has no HEAD/source-build path and no developer toolchain
# dependencies. The ZIP is the same immutable payload resolved by curl.
require "open3"
require "json"

class Jobctrl < Formula
  desc "Local-first job search mission control: discover, score, tailor, apply"
  homepage "https://jobctrl.dev"

  url "https://releases.jobctrl.dev/v1/artifacts/0.1.1-726ca08bd893bba2b932cd6b66835a0bf6d56f7f-darwin-arm64/jobctrl-0.1.1-darwin-arm64.zip"
  version "0.1.1"
  sha256 "30745567c8f28852f077079d7bd3135b966fd0ef4477b256e324798e31810a3e"
  license "AGPL-3.0-only"
  version_scheme 1

  JOBCTRL_BUILD_ID = "0.1.1-726ca08bd893bba2b932cd6b66835a0bf6d56f7f-darwin-arm64"
  JOBCTRL_MANIFEST_SHA256 = "3c79d79a3d218d51a934b6de79c7a3a2df9ade3d54e1c5cffe703d6ee891649b"
  JOBCTRL_DESCRIPTOR_URL = "https://releases.jobctrl.dev/v1/artifacts/0.1.1-726ca08bd893bba2b932cd6b66835a0bf6d56f7f-darwin-arm64/release-descriptor.json"
  JOBCTRL_DESCRIPTOR_SHA256 = "78b1bb105b4a1022c7e0210552732ffeb6327d5b77cccf79f4893df72f973f9c"
  JOBCTRL_SIGNATURE_SHA256 = "de3ce729962fed0047c0deeb9d0a33897dd2555d55bdc86eeda1ec508e6e79af"

  resource "jobctrl-release-descriptor" do
    url JOBCTRL_DESCRIPTOR_URL
    sha256 JOBCTRL_DESCRIPTOR_SHA256
  end

  resource "jobctrl-release-descriptor-signature" do
    url "#{JOBCTRL_DESCRIPTOR_URL}.sig"
    sha256 JOBCTRL_SIGNATURE_SHA256
  end

  def verify_notarized_app!(bundle)
    codesign_output, codesign_status = Open3.capture2e(
      "/usr/bin/codesign",
      "--verify",
      "--deep",
      "--strict",
      "--check-notarization",
      "-R=notarized",
      "--verbose=2",
      bundle.to_s,
    )
    unless codesign_status.success?
      odie "JobCtrl release signature verification failed for #{bundle}: #{codesign_output}"
    end

    gatekeeper_output, gatekeeper_status = Open3.capture2e(
      "/usr/sbin/spctl",
      "--assess",
      "--type",
      "execute",
      "--verbose=4",
      bundle.to_s,
    )
    if !gatekeeper_status.success? || gatekeeper_output.exclude?("source=Notarized Developer ID")
      odie "JobCtrl release is not Gatekeeper-notarized for #{bundle}: #{gatekeeper_output}"
    end
  end

  def verify_notarized_executable!(executable)
    codesign_output, codesign_status = Open3.capture2e(
      "/usr/bin/codesign",
      "--verify",
      "--strict",
      "--check-notarization",
      "-R=notarized",
      "--verbose=2",
      executable.to_s,
    )
    unless codesign_status.success?
      odie "JobCtrl release executable signature verification failed for #{executable}: #{codesign_output}"
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
    verify_notarized_executable!(buildpath/"launcher/jobctrl")
    verify_notarized_executable!(buildpath/"launcher/jobctrl-installer")
    verify_notarized_executable!(managed_headless_shell)
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
    <<~EOS
      JobCtrl #{version} (#{JOBCTRL_BUILD_ID}) uses the same signed ZIP and
      manifest as the curl channel. It has no Homebrew dependencies and no
      source checkout. The verified ZIP privately bundles Node, Python,
      Temporal, and one managed core Chromium; Git, Corepack, uv, Poppler, and
      system Chrome are not required unless you explicitly enable an
      authenticated-browser capability.
    EOS
  end

  test do
    assert_path_exists libexec/"bootstrap"/"homebrew-bootstrap.json"
    assert_predicate bin/"jobctrl", :symlink?
  end
end
