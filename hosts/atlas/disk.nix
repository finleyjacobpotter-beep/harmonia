# Atlas's disk, for disko: GPT on the first NVMe drive with a 1 GiB ESP and
# ext4 for the rest. nixos-anywhere wipes the disk and creates this before
# installing.
#
# The MS-01 has three M.2 slots, so nvme0n1 is not always the drive you
# mean. Run `ls -l /dev/disk/by-id/` on the machine first and put the
# drive's nvme-… path here if there is more than one.
{
  disko.devices.disk.main = {
    type = "disk";
    device = "/dev/nvme0n1";
    content = {
      type = "gpt";
      partitions = {
        ESP = {
          size = "1G";
          type = "EF00";
          content = {
            type = "filesystem";
            format = "vfat";
            mountpoint = "/boot";
            mountOptions = [ "umask=0077" ];
          };
        };
        root = {
          size = "100%";
          content = {
            type = "filesystem";
            format = "ext4";
            mountpoint = "/";
          };
        };
      };
    };
  };
}
