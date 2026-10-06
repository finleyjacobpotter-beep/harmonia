# Shared by every host and microVM guest: git with Git LFS, installed system
# wide and its filters registered in /etc/gitconfig, so LFS repos check out
# their real files instead of pointer stubs.
{
  programs.git = {
    enable = true;
    lfs.enable = true;
  };
}
