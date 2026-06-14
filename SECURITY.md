# Security Policy

## Reporting a vulnerability

If you discover a security issue in this repository, please **do not** open a public issue.

Instead, use GitHub's private vulnerability reporting:
**Repository → Security → Report a vulnerability**

You can expect:
- An acknowledgement within 3 business days
- A remediation plan or status update within 10 business days
- Credit in release notes once a fix ships, if you'd like it

## Scope

In scope:
- `cns-deployment-docs.html` — the static web app
- `get-device-info-*.{sh,ps1}` and the launchers — the privileged helper scripts
- Anything in `.github/workflows/` — pipeline and supply-chain concerns

Out of scope:
- Findings that require a compromised admin/maintainer account
- Social engineering of student workers or staff
- Issues in third-party services (GitHub, Google Fonts)
