# Flash drives at /mnt/<filesystem UUID>, mounted and unmounted from the
# dash's usb and disk tiles (home/eww/usb.py, home/eww/eww.yuck) without a
# password.
#
# Each drive is an instance of harmonia-usb-mount@, named by its UUID
# escaped for systemd (1A2B\x2d3C4D for 1A2B-3C4D): starting it mounts the
# drive, stopping it unmounts. It is bound to the drive's device unit, so
# pulling the drive out stops it too. Only filesystems on a USB disk are
# mounted, and only wheel may start or stop these units (polkit, below).
{ pkgs, lib, ... }:
let
  mount = pkgs.writeShellApplication {
    name = "harmonia-usb-mount";
    runtimeInputs = with pkgs; [
      coreutils
      util-linux
      systemd
    ];
    text = ''
      action=$1 uuid=$2
      [[ $uuid =~ ^[A-Za-z0-9-]+$ ]] || { echo "not a filesystem UUID: $uuid" >&2; exit 1; }
      dir=/mnt/$uuid
      dev=/dev/disk/by-uuid/$uuid

      case $action in
        mount)
          [[ -e $dev ]] || { echo "no filesystem with UUID $uuid" >&2; exit 1; }
          # The disk the filesystem is on must hang off USB.
          [[ $(udevadm info --query=property --property=ID_BUS --value "$dev") == usb ]] \
            || { echo "$dev is not on a USB disk" >&2; exit 1; }
          mountpoint -q "$dir" && exit 0
          fstype=$(blkid -o value -s TYPE "$dev")
          # Filesystems without owners are given to the users group, so
          # the desktop user can write to them; the rest keep their own.
          case $fstype in
            vfat | exfat | ntfs | ntfs3) opts=nosuid,nodev,gid=users,umask=0002 ;;
            *) opts=nosuid,nodev ;;
          esac
          mkdir -p "$dir"
          mount -o "$opts" "$dev" "$dir" || { rmdir "$dir"; exit 1; }
          ;;
        unmount)
          if mountpoint -q "$dir"; then
            # Pulled out already: nothing to write back, so let go lazily.
            if [[ -e $dev ]]; then umount "$dir"; else umount -l "$dir"; fi
          fi
          rmdir "$dir" 2>/dev/null || true
          ;;
        *)
          echo "usage: harmonia-usb-mount mount|unmount UUID" >&2
          exit 2
          ;;
      esac
    '';
  };
in
{
  # No sandboxing: any mount namespace (PrivateTmp, ProtectSystem, …) would
  # keep the mount inside the service, where nothing else sees it.
  systemd.services."harmonia-usb-mount@" = {
    description = "Mount the USB flash drive %I at /mnt/%I";
    bindsTo = [ "dev-disk-by\\x2duuid-%i.device" ];
    after = [ "dev-disk-by\\x2duuid-%i.device" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${lib.getExe mount} mount %I";
      ExecStop = "${lib.getExe mount} unmount %I";
    };
  };

  # The usb and disk tiles' Mount and Unmount (home/eww/usb.py).
  security.polkit.extraConfig = ''
    polkit.addRule(function (action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          /^harmonia-usb-mount@[A-Za-z0-9\\]+\.service$/.test(action.lookup("unit")) &&
          (action.lookup("verb") == "start" || action.lookup("verb") == "stop") &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';
}
