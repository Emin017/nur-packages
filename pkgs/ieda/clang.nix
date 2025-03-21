{
  lib,
  libcxxStdenv,
  llvmPackages,
  stdenv,
  fetchgit,
  fetchFromGitHub,
  callPackages,
  cmake,
  ninja,
  flex,
  bison,
  zlib,
  tcl,
  boost,
  eigen,
  yaml-cpp,
  pkg-config,
  fixDarwinDylibNames,
  glog,
  gtest,
  gflags,
  metis,
  gmp,
  python3,
  onnxruntime,
}:
let
  glog-lock = glog.overrideAttrs (oldAttrs: rec {
    version = "0.6.0";
    src = fetchFromGitHub {
      owner = "google";
      repo = "glog";
      rev = "v${version}";
      sha256 = "sha256-xqRp9vaauBkKz2CXbh/Z4TWqhaUtqfbsSlbYZR/kW9s=";
    };
  });
  rootSrc = stdenv.mkDerivation {
    pname = "iEDA-src";
    version = "2025-03-12";
    src = fetchgit {
      url = "https://github.com/Emin017/iEDA";
      rev = "2c54945b7e98852535e3fa7df4a61750238ff15f";
      sha256 = "sha256-weYlGDxnuWYlxngB52n471LalacV6vz9jP+LVRyhOms=";
    };

    patches = [
      ./diff.patch
    ];

    dontBuild = true;
    dontFixup = true;

    installPhase = ''
      cp -r . $out
      sed -i '2a\#include <sstream>' $out/src/third_party/LSAssigner4iEDA/ls_assigner/buildmodel/model.cpp
    '';

  };

  rustpkgs = callPackages ./rustpkgs.nix { inherit rootSrc; };
in
libcxxStdenv.mkDerivation {
  pname = "iEDAClang";
  version = "0-unstable-2025-03-12";

  src = rootSrc;

  NIX_CFLAGS_COMPILE = "-D_LIBCPP_DISABLE_AVAILABILITY -isystem ${llvmPackages.libcxx.dev}/include/c++/v1";

  nativeBuildInputs = [
    cmake
    ninja
    flex
    bison
    python3
    tcl
    pkg-config
    fixDarwinDylibNames
  ];

  cmakeFlags = [
    (lib.cmakeBool "CMD_BUILD" true)
    (lib.cmakeBool "SANITIZER" false)
    (lib.cmakeBool "BUILD_STATIC_LIB" false)
  ];

  preConfigure = ''
    cmakeFlags+=" -DCMAKE_RUNTIME_OUTPUT_DIRECTORY:FILEPATH=$out/bin -DCMAKE_LIBRARY_OUTPUT_DIRECTORY:FILEPATH=$out/lib"
  '';

  buildInputs = [
    llvmPackages.openmp
    llvmPackages.libunwind
    rustpkgs.iir-rust
    rustpkgs.sdf_parse
    rustpkgs.spef-parser
    rustpkgs.vcd_parser
    rustpkgs.verilog-parser
    rustpkgs.liberty-parser
    gtest
    glog-lock
    gflags
    boost
    onnxruntime
    eigen
    yaml-cpp
    metis
    gmp
    tcl
    zlib
  ];

  postInstall = ''
    # Tests rely on hardcoded path, so they should not be included
    rm $out/bin/*test $out/bin/*Test $out/bin/test_* $out/bin/*_app
  '';

  enableParallelBuild = true;

  meta = {
    description = "Open-source EDA infracstructure and tools from Netlist to GDS for ASIC design";
    homepage = "https://gitee.com/oscc-project/iEDA";
    license = lib.licenses.mulan-psl2;
    maintainers = with lib.maintainers; [
      xinyangli
      Emin017
    ];
    mainProgram = "iEDA";
    platforms = lib.platforms.all;
  };
}
