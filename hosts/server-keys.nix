# SSH public keys allowed to log in to the servers (proteus, atlas), as root
# and as your user. Password login over SSH is off, so without a key here
# only the console gets in (evaluation warns about it). One string per key:
#
#   [
#     "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... you@harmonia"
#   ]
#
# `cat ~/.ssh/id_ed25519.pub` prints yours (`ssh-keygen -t ed25519` makes
# one).
[ ]
