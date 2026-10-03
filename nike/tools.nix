# The OSCP toolset for the Nike guest: enumeration, web, exploitation,
# password attacks, Active Directory, pivoting and post-exploitation, plus a
# Python environment with the libraries the scripts need. Kept in its own
# module so nike/default.nix stays about the machine, not the packages.
#
# Heavy GUI tools (Burp, the BloodHound UI) are not here: BloodHound runs as a
# container (nike/labs.nix), and Nike is a headless SSH box.
{ pkgs, ... }:
let
  # Python with impacket (which also puts impacket-* example scripts on PATH),
  # the AD/crypto libraries, and pwntools for exploit scripting.
  python = pkgs.python3.withPackages (ps: [
    ps.impacket
    ps.bloodhound # the SharpHound-equivalent Python collector
    ps.pwntools
    ps.requests
    ps.pycryptodome
    ps.ldap3
    ps.dnspython
    # Credential looting and AD, from the 0xsyr0/oscp list.
    ps.lsassy # pull LSASS secrets over SMB
    ps.pypykatz # parse LSASS dumps / registry hives offline
    ps.bloodyad # read and abuse AD objects over LDAP
    ps.dploot # loot DPAPI secrets (like a Python SharpDPAPI)
  ]);
in
{
  environment.systemPackages = with pkgs; [
    python
    penelope # the reverse-shell handler the user asked for

    # ── Enumeration / scanning ──────────────────────────────────────
    nmap
    masscan
    rustscan
    netdiscover
    arp-scan
    nbtscan
    net-snmp # snmpwalk, snmpget
    onesixtyone
    dnsrecon
    dnsenum
    fierce
    dnsutils # dig, nslookup, host
    whois
    traceroute

    # ── SMB / Windows services ──────────────────────────────────────
    samba # smbclient, rpcclient, smbcacls
    smbmap
    smbclient-ng
    enum4linux-ng
    netexec # the crackmapexec successor (nxc)
    responder

    # ── Web ─────────────────────────────────────────────────────────
    gobuster
    feroxbuster
    ffuf
    dirb
    wfuzz
    nikto
    nuclei
    whatweb
    cewl
    sqlmap

    # ── Exploitation ────────────────────────────────────────────────
    metasploit
    exploitdb # searchsploit
    payloadsallthethings

    # ── Password attacks ────────────────────────────────────────────
    hashcat
    hashcat-utils
    john # John the Ripper (jumbo)
    thc-hydra
    medusa
    hashid
    haiti
    crunch
    username-anarchy # generate username lists from real names
    jwt-cli # inspect and forge JSON Web Tokens

    # ── Active Directory ────────────────────────────────────────────
    evil-winrm
    certipy
    kerbrute
    donpapi
    coercer
    adidnsdump
    pretender
    mimikatz
    powersploit
    powershell
    pywhisker # shadow-credentials (msDS-KeyCredentialLink) attack
    keepwn # hunt and crack KeePass databases
    rusthound-ce # fast BloodHound CE collector (Rust), next to bloodhound-python

    # ── Pivoting / tunnelling ───────────────────────────────────────
    ligolo-ng # also run as a container service (nike/labs.nix)
    chisel
    socat
    proxychains-ng
    sshpass
    stunnel
    freerdp # xfreerdp (CLI RDP)

    # ── Shells / listeners ──────────────────────────────────────────
    netcat-gnu # `nc`
    rlwrap

    # ── Post-exploitation / privilege escalation ────────────────────
    linux-exploit-suggester # suggest kernel privesc from `uname`
    pspy # watch processes/cron without root
    firefox_decrypt # recover saved Firefox credentials from a profile

    # ── Reversing / forensics ───────────────────────────────────────
    gdb
    radare2
    ltrace
    binwalk
    exiftool
    steghide
    foremost

    # ── Database clients (for looted creds) ─────────────────────────
    redis
    mariadb # mysql client
    postgresql
    swaks # SMTP testing

    # ── Wordlists ───────────────────────────────────────────────────
    seclists
  ];

  # SecLists and the Payloads collection are big; point the usual names at
  # them so muscle memory (`/usr/share/wordlists`, rockyou) works.
  environment.variables.WORDLISTS = "${pkgs.seclists}/share/wordlists";
  systemd.tmpfiles.rules = [
    "L+ /usr/share/wordlists - - - - ${pkgs.seclists}/share/wordlists"
    "L+ /usr/share/seclists - - - - ${pkgs.seclists}/share/wordlists"
    "L+ /usr/share/payloadsallthethings - - - - ${pkgs.payloadsallthethings}/share/payloadsallthethings"
  ];
}
