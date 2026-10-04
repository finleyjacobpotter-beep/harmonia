# ThinkPad fan control and firmware updates (cadmus).
#
# thinkfan sets the fan speed from the CPU temperature through the
# thinkpad_acpi driver (loaded with fan_control=1 by the NixOS module). The
# curve below is quieter than the firmware's at idle and runs the fan
# flat out from 80 °C. To check it:
#
#   cat /proc/acpi/ibm/fan       current level and RPM
#   sensors                      temperatures (lm_sensors)
#   journalctl -u thinkfan       what thinkfan is doing
#
# To change the curve, edit `levels`: [ fan level, lower °C, upper °C ]. The
# fan steps up a level when the temperature passes the upper bound and back
# down below the lower one. "level auto" hands control back to the firmware,
# so the hottest step can never be quieter than Lenovo's own curve.
{ pkgs, ... }:
{
  services.thinkfan = {
    enable = true;
    sensors = [
      {
        type = "tpacpi";
        query = "/proc/acpi/ibm/thermal";
        # Only the first reading is the CPU; the E14 reports the rest as 0
        # or N/A.
        indices = [ 0 ];
      }
    ];
    fans = [
      {
        type = "tpacpi";
        query = "/proc/acpi/ibm/fan";
      }
    ];
    levels = [
      [ 0 0 55 ]
      [ 1 50 62 ]
      [ 2 57 66 ]
      [ 3 61 70 ]
      [ 5 65 75 ]
      [ 7 70 80 ]
      [ "level auto" 75 32767 ]
    ];
  };

  # BIOS, embedded controller and SSD firmware from LVFS: `fwupdmgr refresh`
  # then `fwupdmgr update`. Lenovo publishes the E14 Gen 2's BIOS there.
  services.fwupd.enable = true;

  environment.systemPackages = [ pkgs.lm_sensors ];
}
