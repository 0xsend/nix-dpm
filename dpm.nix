{ lib, stdenv, autoPatchelfHook, zlib, glibc }:

let
  sources = builtins.fromJSON (builtins.readFile ./dpm-sources.json);

  # Map nix system to dpm platform naming
  platformMap = {
    "x86_64-darwin" = "darwin-amd64";
    "aarch64-darwin" = "darwin-arm64";
    "x86_64-linux" = "linux-amd64";
    "aarch64-linux" = "linux-arm64";
  };

  platform = platformMap.${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");
  hash = sources.hashes.${platform};

  tarball = "dpm-${sources.version}-${platform}.tar.gz";
  url = "https://artifactregistry.googleapis.com/download/v1/projects/da-images/locations/europe/repositories/public-generic/files/dpm-sdk:${sources.version}:${tarball}:download?alt=media";
in
stdenv.mkDerivation rec {
  pname = "dpm";
  version = sources.version;

  src = builtins.fetchurl {
    inherit url;
    sha256 = hash;
    name = tarball;  # Required because URL contains special characters
  };

  # Linux requires patching ELF binaries to find dynamic libraries
  nativeBuildInputs = lib.optionals stdenv.isLinux [ autoPatchelfHook ];
  buildInputs = lib.optionals stdenv.isLinux [ zlib glibc stdenv.cc.cc.lib ];

  dontUnpack = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out
    tar xzf $src -C $out --strip-components=1

    # Ensure bin directory exists and binaries are executable
    chmod +x $out/bin/*

    runHook postInstall
  '';

  # Skip fixup phase on Darwin to avoid code signing issues
  dontFixup = stdenv.isDarwin;

  meta = with lib; {
    description = "Digital Asset Package Manager - CLI tool for DAML SDK";
    homepage = "https://docs.digitalasset.com/build/3.4/dpm/dpm.html";
    license = licenses.asl20;
    platforms = builtins.attrNames platformMap;
    mainProgram = "dpm";
  };
}
