# Host-enforced firewall policies for the libvirt VMs (modules/nixos/vms.nix).
#
# libvirt's nwfilter applies these on the host, on each VM's virtual NIC, so
# nothing inside the guest (root included) can loosen them. Every policy
# starts with libvirt's clean-traffic filter (layer 2): the guest can't fake
# its MAC or IP address or its ARP replies, or send anything but IPv4 and
# ARP. The policies below are the layer-3 rules on top.
#
#   open           anything (the default network's NAT still applies)
#   internet-only  DHCP and DNS from the host's dnsmasq, then the internet only:
#                  no host, no LAN, no other VMs, no link-local
#   (clean-traffic drops IPv6 for every policy; the default network has none)
#   isolated       no network at all
#
# Each VM gets a filter named harmonia-vm-<name> that points at one policy.
# Redefining it (harmonia-vm-firewall) takes effect on a running VM at once.
{ lib }:
let
  # The libvirt "default" network's host address (DHCP + DNS).
  gateway = "192.168.122.1";

  # Private, shared and link-local ranges the internet-only policy blocks.
  blocked = [
    {
      ip = "10.0.0.0";
      mask = "8";
    }
    {
      ip = "172.16.0.0";
      mask = "12";
    }
    {
      ip = "192.168.0.0";
      mask = "16";
    }
    {
      ip = "100.64.0.0";
      mask = "10";
    }
    {
      ip = "169.254.0.0";
      mask = "16";
    }
  ];

  filter = name: body: ''
    <filter name="${name}" chain="root">
    ${body}
    </filter>
  '';
in
rec {
  policies = [
    "open"
    "internet-only"
    "isolated"
  ];

  # Shared policy filters, one per entry in `policies`. "out" is traffic
  # from the VM; accept rules are stateful, so replies come back in.
  policyFilters = {
    open = filter "harmonia-open" ''
      <rule action="accept" direction="inout" priority="500"><all/></rule>
    '';

    internet-only = filter "harmonia-internet-only" ''
      <rule action="accept" direction="out" priority="100"><udp dstportstart="67" dstportend="67"/></rule>
      <rule action="accept" direction="in" priority="100"><udp srcipaddr="${gateway}" srcportstart="67" srcportend="67" dstportstart="68" dstportend="68"/></rule>
      <rule action="accept" direction="out" priority="110"><udp dstipaddr="${gateway}" dstportstart="53" dstportend="53"/></rule>
      <rule action="accept" direction="out" priority="110"><tcp dstipaddr="${gateway}" dstportstart="53" dstportend="53"/></rule>
      <rule action="drop" direction="out" priority="200"><all dstipaddr="${gateway}"/></rule>
      ${lib.concatMapStrings (
        b: "<rule action=\"drop\" direction=\"out\" priority=\"200\"><all dstipaddr=\"${b.ip}\" dstipmask=\"${b.mask}\"/></rule>\n"
      ) blocked}
      <rule action="accept" direction="out" priority="500"><all/></rule>
      <rule action="drop" direction="inout" priority="900"><all/></rule>
    '';

    isolated = filter "harmonia-isolated" ''
      <rule action="drop" direction="inout" priority="900"><all/></rule>
    '';
  };

  # The per-VM filter: anti-spoofing, the VM's own extra rules, then its policy.
  # `extraRules` is raw nwfilter <rule> XML, checked before the policy
  # (give them a priority below 100 to win over it).
  vmFilter =
    name: fw:
    assert lib.assertMsg (lib.elem fw.policy policies)
      "harmonia VM ${name}: firewall.policy must be one of ${toString policies}, not ${fw.policy}";
    filter "harmonia-vm-${name}" ''
      <filterref filter="clean-traffic"/>
      ${fw.extraRules or ""}
      <filterref filter="harmonia-${fw.policy}"/>
    '';
}
