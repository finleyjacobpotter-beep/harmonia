# Tulasi — hand-drawn 32×32 pixel-art icon theme by Shringar Studio.
#
# Upstream inherits from breeze/Adwaita, which mixes other icon styles in
# wherever Tulasi has no icon. Instead this build fills every gap with one of
# Tulasi's own icons:
#
#   apps                          → emblem-question (the purple "?" tile)
#   files / mimetypes             → document-properties
#   folders                       → folder
#   hardware                      → computer
#   anything else                 → dialog-question
#
# "Every gap" means every standard icon name (taken from adwaita-icon-theme)
# plus every Icon= named by the desktop files in `appPackages`. The theme
# then inherits only from hicolor, which the icon spec always searches last.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  gtk3,
  adwaita-icon-theme,
  # Packages whose share/applications/*.desktop Icon= names should resolve
  # to Tulasi icons (see home/gtk.nix).
  appPackages ? [ ],
}:
let
  appDirs = map (p: "${p}") (lib.filter lib.isDerivation appPackages);
in
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
    chmod -R u+w $theme
    mkdir -p $theme/scalable/{mimetypes,categories}

    # No breeze/Adwaita — only the spec-mandated hicolor.
    sed -i 's/^Inherits=.*/Inherits=hicolor/' $theme/index.theme

    declare -A have
    while IFS= read -r f; do
      n=''${f##*/}; n=''${n%.svg}
      have[$n]=1
    done < <(find $theme/scalable -name '*.svg')

    # generic <icon name> <context hint> → path relative to scalable/<dir>/
    generic() {
      local name=$1 ctx=$2 base
      case "$ctx:$name" in
        apps:* | *:application-x-executable* | *:application-default-icon*)
          base=../emblems/emblem-question
          ;;
        *:image-missing*) base=../status/dialog-question ;;
        *:folder*|*:inode-directory*|*:user-home*|*:user-desktop*|*:user-trash*|places:*)
          base=../places/folder ;;
        *:drive-*|*:media-*|*:input-*|*:computer*|*:phone*|*:printer*|*:camera-*|*:scanner*|*:battery*|*:audio-card*|*:audio-headset*|*:audio-speakers*|*:video-display*|devices:*)
          base=../devices/computer ;;
        mimetypes:*|*:text-*|*:image-*|*:audio-x-*|*:video-x-*|*:font-*|*:model-*|*:package-*|*:application-*|*:x-office-*)
          base=../actions/document-properties ;;
        *) base=../status/dialog-question ;;
      esac
      # keep symbolic requests symbolic when Tulasi has a symbolic variant
      if [[ $name == *-symbolic && -e $theme/scalable/''${base#../}-symbolic.svg ]]; then
        base=$base-symbolic
      fi
      echo "$base.svg"
    }

    fill() {
      local name=$1 ctx=$2 dir
      [[ -n $name && -z ''${have[$name]:-} ]] || return 0
      case $ctx in
        apps|places|devices|mimetypes|categories|status|emblems|actions) dir=$ctx ;;
        *) dir=status ;;
      esac
      ln -s "$(generic "$name" "$ctx")" "$theme/scalable/$dir/$name.svg"
      have[$name]=1
    }

    # 1. standard names, context taken from Adwaita's directory layout
    while IFS= read -r f; do
      ctx=''${f%/*}; ctx=''${ctx##*/}
      n=''${f##*/}; n=''${n%.*}
      case $ctx in
        ui|legacy|emotes) ctx=other ;;
      esac
      fill "$n" "$ctx"
    done < <(find ${adwaita-icon-theme}/share/icons/Adwaita \( -name '*.svg' -o -name '*.png' \) -not -path '*/cursors/*')

    # 2. icons named by installed applications
    for d in ${lib.escapeShellArgs appDirs}; do
      [ -d "$d/share/applications" ] || continue
      while IFS= read -r icon; do
        [[ $icon == /* ]] && continue
        icon=''${icon%.svg}; icon=''${icon%.png}
        fill "$icon" apps
      done < <(find -L "$d/share/applications" -name '*.desktop' -exec sed -n 's/^Icon=//p' {} + 2>/dev/null)
    done

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
