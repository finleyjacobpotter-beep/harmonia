# Tulasi — hand-drawn 32×32 pixel-art icon theme by Shringar Studio.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  gtk3,
}:
stdenvNoCC.mkDerivation {
  pname = "tulasi-icon-theme";
  version = "0.3-unstable-2026-09-16";

  src = fetchFromGitHub {
    owner = "ShringarStudio";
    repo = "Tulasi";
    rev = "b23e3813dc2614c130a793cae3f594a45fd8959c";
    hash = "sha256-26pCjNGdroHCTszFgcqLJP02sTos2dQy1VXXGsR0HI0=";
  };

  nativeBuildInputs = [ gtk3 ];

  dontBuild = true;
  dontDropIconThemeCache = true;

  # The repo root is the theme; `cow/` holds source art and isn't referenced.
  installPhase = ''
    runHook preInstall
    theme=$out/share/icons/Tulasi
    mkdir -p $theme
    cp -r index.theme scalable $theme/
    gtk-update-icon-cache --force --ignore-theme-index $theme
    runHook postInstall
  '';

  meta = {
    description = "Pixel-art icon theme for Linux by Shringar Studio";
    homepage = "https://github.com/ShringarStudio/Tulasi";
    license = lib.licenses.cc-by-nc-sa-40;
    platforms = lib.platforms.linux;
  };
}
