# pi, the coding agent (earendil-works/pi, MIT): the release build, pinned.
# nixpkgs' pi-coding-agent is 0.87, from before pi had MCP built in (0.99),
# so this is the upstream release: a Bun executable with its runtime
# appended (patched for NixOS's loader, never stripped), next to the docs,
# themes and native add-ons it reads from its own folder.
#
# Updates come from here: bump the version and take the hashes from the
# release's SHA256SUMS (`nix hash convert --to sri <hex>`).
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  libxcb,
}:
let
  version = "1.1.0";
  assets = {
    x86_64-linux = {
      name = "pi-linux-x64.tar.gz";
      hash = "sha256-P6qUZmzThJ03rzIP90lAfQJxsHqblPQgyH4whm4Q4ok=";
    };
    aarch64-linux = {
      name = "pi-linux-arm64.tar.gz";
      hash = "sha256-87DKxFn531Qg5OSLSOldgb+rV7cB3T/ksI/afRHSfas=";
    };
  };
  asset =
    assets.${stdenv.hostPlatform.system}
      or (throw "pi: no release build for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "pi";
  inherit version;

  src = fetchurl {
    url = "https://github.com/earendil-works/pi/releases/download/v${version}/${asset.name}";
    inherit (asset) hash;
  };

  dontStrip = true;
  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];
  # The X11 clipboard add-on.
  buildInputs = [ libxcb ];

  # No install telemetry, and no "new version" nags: the version is the one
  # above.
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib
    cp -r . $out/lib/pi
    makeWrapper $out/lib/pi/pi $out/bin/pi \
      --set-default PI_TELEMETRY 0 \
      --set-default PI_SKIP_VERSION_CHECK 1
    runHook postInstall
  '';

  meta = {
    description = "pi, a minimal terminal coding agent";
    homepage = "https://pi.dev";
    license = lib.licenses.mit;
    mainProgram = "pi";
    platforms = builtins.attrNames assets;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
