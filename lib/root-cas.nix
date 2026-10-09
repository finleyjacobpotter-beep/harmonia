# Extra root CAs to trust on one machine: every .crt or .pem file in
# certs/all/ and certs/<name>/ (name = the hostname, or nike) is added to
# its system trust store. See certs/README.md.
#
#   imports = [ (import ../lib/root-cas.nix "nike") ];
name:
{ lib, ... }:
let
  filesIn =
    dir:
    lib.optionals (builtins.pathExists dir) (
      map (f: dir + "/${f}") (
        builtins.filter (f: lib.hasSuffix ".crt" f || lib.hasSuffix ".pem" f) (
          builtins.attrNames (lib.filterAttrs (_: type: type == "regular") (builtins.readDir dir))
        )
      )
    );
  certs = filesIn ../certs/all ++ filesIn (../certs + "/${name}");
  bundle = "/etc/ssl/certs/ca-certificates.crt";
in
lib.mkIf (certs != [ ]) {
  security.pki.certificateFiles = certs;

  # OpenSSL, curl, git, Go and Rust tools read the system bundle already;
  # Python's requests and Node/Bun (Claude Code, opencode) need telling.
  environment.variables = {
    REQUESTS_CA_BUNDLE = bundle;
    NODE_EXTRA_CA_CERTS = bundle;
  };
}
