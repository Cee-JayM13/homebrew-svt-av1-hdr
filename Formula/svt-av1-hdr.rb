class SvtAv1Hdr < Formula
  desc "SVT-AV1-HDR – bleeding-edge perceptual AV1 encoder (main branch) with optimizations for visually-optimal SDR/HDR encoding"
  homepage "https://github.com/juliobbv-p/svt-av1-hdr/"
  license "BSD-3-Clause"

  head "https://github.com/juliobbv-p/svt-av1-hdr.git", branch: "main"

  depends_on "cmake" => :build
  depends_on "nasm" => :build
  depends_on "libdovi"
  depends_on "hdr10plus"
  
  # Optional but recommended deps for full features (add if desired)
  # depends_on "libdovi" => :optional     # for Dolby Vision support
  # depends_on "hdr10plus" => :optional   # for HDR10+ support

  def install
    # HEAD builds may have new features/fixes; use Release for best perf
    # Features auto-detected at runtime via compiler/runtime_cpu_detection
    ENV.runtime_cpu_detection

    # Explicit Release build dir (matches upstream & your original pattern)
    mkdir "Bin/Release" do
      system "cmake", buildpath,
                      "-DCMAKE_BUILD_TYPE=Release",
                      "-DCMAKE_INSTALL_PREFIX=#{prefix}",
                      *std_cmake_args
      system "cmake", "--build", ".", "--", "-j", ENV.make_jobs.to_s
      system "cmake", "--install", "."
    end
  end

  test do
    resource "homebrew-testvideo" do
      url "https://github.com/grusell/svt-av1-homebrew-testdata/raw/main/video_64x64_yuv420p_25frames.yuv"
      sha256 "0c5cc90b079d0d9c1ded1376357d23a9782a704a83e01731f50ccd162e246492"
    end

    testpath.install resource("homebrew-testvideo")
    system bin/"SvtAv1EncApp", "-w", "64", "-h", "64", "-i", "video_64x64_yuv420p_25frames.yuv", "-b", "output.ivf"
    assert_path_exists testpath/"output.ivf"
  end
end