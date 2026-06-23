class SvtAv1Hdr < Formula
  desc "SVT-AV1-HDR – bleeding-edge perceptual AV1 encoder (main branch) with optimizations for visually-optimal SDR/HDR encoding"
  homepage "https://github.com/juliobbv-p/svt-av1-hdr/"
  license "BSD-3-Clause"

  head "https://github.com/juliobbv-p/svt-av1-hdr.git", branch: "main"

  depends_on "cargo-c" => :build
  depends_on "cmake" => :build
  depends_on "nasm" => :build
  depends_on "pkgconf" => :build
  depends_on "rust" => :build
  depends_on "dovi_tool"
  # hdr10plus_tool (the CLI) does not ship libhdr10plus_rs — we clone the
  # source repo and build the C library ourselves in the install block below.

  # Pin to the same upstream tag that Homebrew's hdr10plus_tool formula tracks
  # so the library version stays consistent with the CLI already on disk.
  resource "hdr10plus_tool_src" do
    url "https://github.com/quietvoid/hdr10plus_tool/archive/refs/tags/1.7.2.tar.gz"
    sha256 "cc917e769bad85323c7f596179798cc96ac878a01ddfd53b210fecae4c891849"
  end

  def install
    ENV.runtime_cpu_detection

    # ── Step 1: build and install libhdr10plus_rs ──────────────────────────
    # The Homebrew hdr10plus_tool formula only installs the CLI binary — it
    # has no lib/, no include/, and no .pc file.  We therefore build the C
    # library ourselves from the upstream source, mirroring exactly how the
    # official dovi_tool formula handles libdovi via `cargo cinstall`.
    resource("hdr10plus_tool_src").stage do
      cd "hdr10plus" do
        system "cargo", "cinstall",
               "--jobs",   ENV.make_jobs.to_s,
               "--release",
               "--locked",
               "--prefix",  prefix,
               "--libdir",  lib
      end
    end

    # ── Step 2: expose both pkg-config files to CMake ─────────────────────
    # libdovi's .pc lives under dovi_tool's own Homebrew opt prefix.
    # libhdr10plus_rs's .pc was just installed into our formula's lib/.
    ENV.prepend_path "PKG_CONFIG_PATH", "#{Formula["dovi_tool"].opt_lib}/pkgconfig"
    ENV.prepend_path "PKG_CONFIG_PATH", "#{lib}/pkgconfig"

    # ── Step 3: build SVT-AV1-HDR with both HDR libraries linked in ───────
    mkdir "Bin/Release" do
      system "cmake", buildpath,
                      "-DCMAKE_BUILD_TYPE=Release",
                      "-DCMAKE_INSTALL_PREFIX=#{prefix}",
                      # Dolby Vision — points to the already-installed dovi_tool Homebrew formula
                      "-DLIBDOVI_FOUND=1",
                      "-DLIBDOVI_INCLUDE_DIRS=#{Formula["dovi_tool"].opt_include}",
                      "-DLIBDOVI_LIBRARIES=#{Formula["dovi_tool"].opt_lib}/libdovi.dylib",
                      # HDR10+ — points to the library we just built in Step 1
                      "-DLIBHDR10PLUS_RS_FOUND=1",
                      "-DLIBHDR10PLUS_RS_INCLUDE_DIRS=#{include}",
                      "-DLIBHDR10PLUS_RS_LIBRARIES=#{lib}/libhdr10plus_rs.dylib",
                      *std_cmake_args
      system "cmake", "--build", ".", "--", "-j", ENV.make_jobs.to_s
      system "cmake", "--install", "."
    end
  end

  test do
    # Verify both HDR feature flags were actually compiled in.
    # SVT-AV1-HDR prints a feature list on --version that includes
    # "DoVi" and "HDR10+" when the respective libraries were linked.
    version_output = shell_output("#{bin}/SvtAv1EncApp --version 2>&1")
    assert_match "DoVi",   version_output, "Binary was NOT built with Dolby Vision (libdovi) support!"
    assert_match "HDR10+", version_output, "Binary was NOT built with HDR10+ (libhdr10plus_rs) support!"

    resource "homebrew-testvideo" do
      url "https://github.com/grusell/svt-av1-homebrew-testdata/raw/main/video_64x64_yuv420p_25frames.yuv"
      sha256 "0c5cc90b079d0d9c1ded1376357d23a9782a704a83e01731f50ccd162e246492"
    end

    testpath.install resource("homebrew-testvideo")
    system bin/"SvtAv1EncApp", "-w", "64", "-h", "64", "-i", "video_64x64_yuv420p_25frames.yuv", "-b", "output.ivf"
    assert_path_exists testpath/"output.ivf"
  end
end
