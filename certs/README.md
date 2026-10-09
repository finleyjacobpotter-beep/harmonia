# Root CAs

Drop a root CA certificate (PEM, ending in `.crt` or `.pem`) in one of these
folders, `git add` it and `rebuild`, and that machine trusts it:

| Folder | Trusted by |
| --- | --- |
| `certs/all/` | the host and Nike |
| `certs/harmonia/` | the host |
| `certs/nike/` | Nike |

For example, to let Nike's tools go through a ZAP or Burp proxy, export its
CA certificate and save it as `certs/nike/zap.crt`. A DER file (`.der`,
`.cer`) needs converting first:

```sh
openssl x509 -inform der -in burp.der -out certs/nike/burp.crt
```

The certificate joins the system bundle (`/etc/ssl/certs/ca-certificates.crt`),
which OpenSSL, curl, git, wget, Go and Rust programs use. When any extra CA
is present, `REQUESTS_CA_BUNDLE` (Python requests) and `NODE_EXTRA_CA_CERTS`
(Node and Bun, so Claude Code and omo) point at that bundle too.
Browsers and Java keep their own stores.

These are public certificates, not keys: never put a CA's private key here.
The folders are empty in this repository; the build skips a missing folder.
