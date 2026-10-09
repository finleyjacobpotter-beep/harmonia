# OmO Native, oh-my-openagent's standalone agent (`omo`, code-yeongyu/
# oh-my-openagent, Sustainable Use License): the release binary, pinned.
# It's a Bun executable with its runtime appended, so it's patched for
# NixOS's loader and never stripped. On first run it unpacks that runtime
# into ~/.omo/binary-runtime/<version>.
#
# Updates come from here, not `omo update`: bump the version and take the
# hashes from the release's SHA256SUMS (`nix hash convert --to sri <hex>`).
{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
}:
let
  version = "5.1.29";
  assets = {
    x86_64-linux = {
      name = "omo-linux-x64";
      hash = "sha256-dfI87E6c9DWw4oHC8CZ3sS4VkH0wDwhGFES2oSwmnvc=";
    };
    aarch64-linux = {
      name = "omo-linux-arm64";
      hash = "sha256-KAIF3DDjPgC0OET+5cmwRlKOeHzJldZg7ZctZ/lfv1w=";
    };
  };
  asset =
    assets.${stdenv.hostPlatform.system}
      or (throw "omo: no release binary for ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "omo";
  inherit version;

  src = fetchurl {
    url = "https://github.com/code-yeongyu/oh-my-openagent/releases/download/v${version}/${asset.name}";
    inherit (asset) hash;
  };

  dontUnpack = true;
  dontStrip = true;
  nativeBuildInputs = [
    autoPatchelfHook
    makeWrapper
  ];

  # No anonymous telemetry, and no "new version" nags: the version is the
  # one above.
  installPhase = ''
    runHook preInstall
    install -Dm755 $src $out/libexec/omo
    makeWrapper $out/libexec/omo $out/bin/omo \
      --set-default OMO_SEND_ANONYMOUS_TELEMETRY 0 \
      --set-default PI_SKIP_VERSION_CHECK 1
    runHook postInstall
  '';

  meta = {
    description = "OmO, oh-my-openagent's standalone coding agent";
    homepage = "https://omo.dev";
    license = lib.licenses.sustainableUse;
    mainProgram = "omo";
    platforms = builtins.attrNames assets;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
