# r2mcp, radare2's MCP server (radareorg/radare2-mcp, MIT): binary analysis
# with radare2 for AI agents, over stdio. Not in nixpkgs; built against
# nixpkgs' radare2, pinned to a release.
{
  lib,
  stdenv,
  fetchFromGitHub,
  meson,
  ninja,
  pkg-config,
  radare2,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "r2mcp";
  version = "1.8.8";

  src = fetchFromGitHub {
    owner = "radareorg";
    repo = "radare2-mcp";
    rev = finalAttrs.version;
    hash = "sha256-ttx+lklMiXxFmSVAVAgPPuI3iMTLQGDacyakY3aVF4Q=";
  };

  nativeBuildInputs = [
    meson
    ninja
    pkg-config
  ];
  buildInputs = [ radare2 ];

  meta = {
    description = "MCP server for radare2";
    homepage = "https://github.com/radareorg/radare2-mcp";
    license = lib.licenses.mit;
    mainProgram = "r2mcp";
    platforms = lib.platforms.unix;
  };
})
