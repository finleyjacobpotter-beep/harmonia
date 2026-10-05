# Shared by every host and microVM guest: sudo echoes an asterisk for each
# character of the password you type.
{
  security.sudo.extraConfig = ''
    Defaults pwfeedback
  '';
}
