class McRbdynUrdf < Formula
  desc "ROS-free URDF parser to create RBDyn structures"
  homepage "https://github.com/jrl-umi3218/mc_rbdyn_urdf/"
  url "https://github.com/jrl-umi3218/mc_rbdyn_urdf/releases/download/v1.1.0/mc_rbdyn_urdf-v1.1.0.tar.gz"
  sha256 "54dc59c865fdf5006be2f2cfb6dcac071cb1ff7049df5c2067c93fa1f3aefd90"
  license "BSD-2-Clause"
  revision 2

  bottle do
    root_url "https://github.com/mc-rtc/homebrew-mc-rtc/releases/download/mc_rbdyn_urdf-1.1.0_2"
    sha256 cellar: :any,                 catalina:     "aed867f0a8c9d16525cef20ff64d9d45f845c894af4981ed6973510c14d4035a"
    sha256 cellar: :any_skip_relocation, x86_64_linux: "b047a7a97bfb63164d3e8cddc05152e0dfcbaeddd481eca40e51c8c329c70e62"
  end

  depends_on "cmake" => [:build, :test]
  depends_on "cython" => :build
  depends_on "rbdyn"

  resource "urdf" do
    url "https://raw.githubusercontent.com/jrl-umi3218/RBDyn/v1.4.0/tests/ParsersTestUtils.h"
    sha256 "48d44698adcb6eb84d8a0c7e88488d501d62f2e4157754a20afe1e683675e03e"
  end

  def install
    xy = Language::Python.major_minor_version Formula["python"].opt_bin/"python3"
    ENV.prepend_create_path "PYTHONPATH", Formula["cython"].opt_libexec/"lib/python#{xy}/site-packages"

    ENV["HOMEBREW_ARCHFLAGS"] = "-march=#{Hardware.oldest_cpu}" unless build.bottle?

    args = std_cmake_args + %W[
      -DINSTALL_DOCUMENTATION:BOOL=OFF
      -DPIP_INSTALL_PREFIX=#{prefix}
      -DPYTHON_BINDING_FORCE_PYTHON3:BOOL=ON
    ]

    system "cmake", "-S", ".", "-B", "build", *args
    system "cmake", "--build", "build"
    system "cmake", "--install", "build"
  end

  test do
    resource("urdf").stage testpath

    (testpath/"CMakeLists.txt").write <<~EOS
      cmake_minimum_required(VERSION 3.1)
      project(Brewmc_rbdyn_urdf LANGUAGES CXX)
      find_package(mc_rbdyn_urdf REQUIRED)
      add_executable(main main.cpp)
      target_link_libraries(main PUBLIC mc_rbdyn_urdf::mc_rbdyn_urdf)
    EOS
    (testpath/"main.cpp").write <<~EOS
      #include <RBDyn/CoM.h>
      #include <mc_rbdyn_urdf/urdf.h>
      #include <iostream>

      #include "ParsersTestUtils.h"

      int main() {
        std::cout << "Loading robot\\n";
        auto robot = mc_rbdyn_urdf::rbdyn_from_urdf(XYZSarmUrdf);
        std::cout << "Robot has: " << robot.mb.nrDof() << " dof\\n";
        double mass = 0.0;
        for(const auto & b : robot.mb.bodies())
        {
          mass += b.inertia().mass();
        }
        std::cout << "Robot mass: " << mass << "\\n";
        std::cout << "Compute CoM\\n";
        auto com = rbd::computeCoM(robot.mb, robot.mbc);
        std::cout << "CoM: " << com.transpose() << "\\n";
        return 0;
      }
    EOS
    # Avoid introducing march=native which will cause ABI breaks
    ENV["CXXFLAGS"] = ""
    system "cmake", ".", *std_cmake_args
    system "cmake", "--build", "."
    system "./main"

    system Formula["python"].opt_bin/"python3", "-c", <<~EOS
      import mc_rbdyn_urdf
    EOS
  end
end
