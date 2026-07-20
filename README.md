# CNS IT Deployment Pipeline

A sanitized public portfolio version of an IT deployment workflow I designed for use by student workers in a higher-education IT support environment.

The operational version is maintained separately in an authorized enterprise repository and is actively used to standardize computer deployments, equipment pickups, reimaging tasks, device-information collection, and support documentation.

This public repository demonstrates the project's general architecture, cross-platform automation, secure CI/CD pipeline, and application-security controls. It does not contain production data, credentials, internal infrastructure details, restricted documentation, or confidential user information.

> **Disclaimer:** This is an independently maintained public portfolio repository. It is not the operational repository and is not an official University of Texas at Austin product, service, or publication.

## Real-World Use

I originally designed this workflow to help student workers perform IT deployment tasks more consistently and accurately.

The enterprise version is used as part of an operational support workflow. It helps technicians:

* Gather standardized Windows and macOS device information
* Prepare consistent ServiceNow work notes
* Generate structured team-status messages
* Document imaging, reimaging, pickup, and deployment activities
* Reduce missing information and inconsistent documentation
* Follow a repeatable process across technicians

The public version has been separated from the operational environment and sanitized for portfolio and educational purposes.


## Security Engineering Highlights

This project applies security controls throughout the development and deployment workflow:

* **Static application analysis:** CodeQL scans the JavaScript code and uploads findings in SARIF format.
* **Secret detection:** Gitleaks checks commits for accidentally exposed credentials and sensitive values.
* **Cross-platform script analysis:** ShellCheck and PSScriptAnalyzer inspect Bash and PowerShell scripts, including scripts that may execute with elevated privileges.
* **Least-privilege permissions:** Each GitHub Actions workflow declares only the permissions required for its function.
* **Secretless deployment:** GitHub Pages deployment uses OpenID Connect rather than a long-lived deployment credential.
* **Dependency monitoring:** Dependabot monitors GitHub Actions dependencies for available updates.
* **Documented threat model:** The project identifies risks involving DOM-based XSS, privileged execution, unsafe output paths, external dependencies, and CI/CD supply-chain security.
* **Security roadmap:** Planned improvements include SHA-pinned actions, Content Security Policy, signed PowerShell scripts, SBOM generation, signed release artifacts, and stronger output-path validation.


---

## What's in the repo

```
cns-deployment-docs.html      # The tool itself — pure HTML/CSS/vanilla JS, no build step
RUN-Device-Info.bat           # Windows launcher (right-click → Run as Admin)
get-device-info-win.ps1       # Windows device-info collector
RUN-Device-Info.command       # macOS launcher (double-click)
get-device-info-mac.sh        # macOS device-info collector
.github/
  workflows/
    pages-deploy.yml          # Builds and publishes the site to GitHub Pages
    codeql.yml                # CodeQL static analysis on the JavaScript
    script-lint.yml           # ShellCheck (bash) + PSScriptAnalyzer (PowerShell)
    secret-scan.yml           # Gitleaks (defense-in-depth alongside GitHub native secret scanning)
  dependabot.yml              # Keeps GitHub Actions versions current
.gitleaks.toml                # Gitleaks custom rules
SECURITY.md                   # Vulnerability disclosure
```

---

## How to run locally

The app is a single HTML file with no build step.

```bash
# Just open it in a browser
open cns-deployment-docs.html        # macOS
start cns-deployment-docs.html       # Windows
```

For an exact mirror of the deployed site, serve the file:

```bash
python3 -m http.server 8000
# http://localhost:8000/cns-deployment-docs.html
```

The device-info scripts are run directly on the machine being imaged:

- **Windows:** right-click `RUN-Device-Info.bat` → *Run as Administrator*
- **macOS:** double-click `RUN-Device-Info.command`

Both scripts print device info (model, serial, MAC, encryption status, etc.) and optionally write a timestamped report to a connected USB drive.

---

## The pipeline

```
push / pull_request to main
        │
        ├──▶ CodeQL                  (security-events: write)
        ├──▶ Script linting          (ShellCheck + PSScriptAnalyzer, SARIF upload)
        ├──▶ Gitleaks                (secret scanning)
        │
push to main only
        │
        └──▶ GitHub Pages deploy     (OIDC, environment-gated)
```

Each workflow declares its own least-privilege `permissions:` block. The Pages deploy uses GitHub's OIDC-based deploy action, so no long-lived deploy secret is stored in the repository.

| Workflow | Purpose | Triggers | Output |
|----------|---------|----------|--------|
| `codeql.yml` | JS static analysis with the `security-extended` and `security-and-quality` query suites | push, PR, weekly cron | SARIF → Security tab |
| `script-lint.yml` | Lints the bash and PowerShell helper scripts that run with elevated privileges | push, PR | SARIF → Security tab |
| `secret-scan.yml` | Catches accidental secret commits before they reach `main` | push, PR | Build failure + log |
| `pages-deploy.yml` | Publishes `cns-deployment-docs.html` as `index.html` to GitHub Pages | push to `main`, manual | Live site |

---

## Threat Model and Security Decisions

The application is client-side only and is not designed to transmit collected information to a remote service. This limits the network-facing threat model, but it does not eliminate application, endpoint, data-handling, or software-supply-chain risks.

**Relevant risks for this codebase:**

1. **DOM-based XSS.** The app composes large blocks of HTML using string concatenation and assigns to `innerHTML`. There's an `esc()` helper, but field values also flow into `onclick="copyText(this, '…')"` attributes via a separate `esc4attr()` path. CodeQL's `security-extended` suite is configured specifically to flag this kind of pattern.
2. **Supply chain — external resources.** The HTML pulls IBM Plex from `fonts.googleapis.com` without Subresource Integrity. A compromised CDN response would execute in the page's origin. (See *Looking ahead* below.)
3. **Privileged scripts.** `get-device-info-win.ps1` runs as Administrator. `get-device-info-mac.sh` writes to whatever volume happens to be mounted at `/Volumes/<name>/`. Both deserve lint attention beyond what most candidates would apply to "just a helper script" — hence PSScriptAnalyzer and ShellCheck running against them with SARIF uploaded to the Security tab.
4. **Supply chain — Actions.** Third-party actions are pinned to release tags in this exercise to keep diffs readable; Dependabot is configured to open PRs when newer versions ship. In production this should be tightened to commit SHAs (see *Looking ahead*).
5. **Workflow permissions.** Every workflow sets `permissions:` explicitly at the top. The default `GITHUB_TOKEN` scope in this repo is read-only; each job widens only what it needs (`security-events: write` for SARIF uploads, `pages: write` + `id-token: write` for the OIDC Pages deploy).

### Recommended Repository-Level Controls

The following controls are recommended but should not be assumed to be enabled solely because they are listed here:

- Branch protection on `main`: require PR, require status checks (all of the above workflows), require linear history, prohibit force-push.
- GitHub native secret scanning + push protection.
- Dependabot alerts and security updates.
- Restrict who can approve workflow runs from forks.
- Require signed commits on `main`.

---

## Planned Security Hardening

The following controls are not currently represented as fully implemented in this public portfolio version. They would be evaluated before using this version as a production application:

- **Pin actions to commit SHAs.** Tags are mutable; SHAs aren't. Dependabot supports SHA pinning with comments preserving the version.
- **Replace inline event handlers.** The `onclick="…"` attributes in the HTML block any meaningful Content-Security-Policy. Moving to `addEventListener` would let me ship `script-src 'self'` and drop the XSS surface meaningfully.
- **Add SRI to the Google Fonts link.** Or self-host the font and drop the external dependency entirely.
- **Sign the PowerShell script.** And document the org-level execution policy that requires signed scripts.
- **Harden the USB write path in the bash script.** It currently iterates `/Volumes/*/` and writes to the first writable volume that isn't `Macintosh HD`. That's a predictable, attacker-influenced path. A safer version would require the script to be explicitly told where to write.
- **Generate an SBOM** (CycloneDX via `anchore/sbom-action`) on release and attach it as a release artifact, along with cosign-signed artifacts.
- **Add accessibility and HTML validation** to the pipeline (`html-validate`, axe). They aren't security per se, but they're cheap quality gates that catch real regressions.

---

## License & contact

See `SECURITY.md` for vulnerability reporting.
