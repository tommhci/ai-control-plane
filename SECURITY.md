# Security Policy

## Reporting a vulnerability

Please report security issues **privately**, not in a public issue.

Use GitHub's private vulnerability reporting for this repository:
**Security and quality** tab → **Report a vulnerability**.

If that option is unavailable to you, open a minimal public issue that asks for
a private channel and contains **no technical detail** in it.

A useful report includes: the affected script or hook, the commit you tested,
what an attacker gains, and a minimal reproduction.

## Scope

This repository is governance and tooling for AI coding agents: PowerShell
scripts, git hooks, installers, protocols, and skills. In scope:

- A hook or installer that fails **open** when it should fail **closed**
- A bypass of the protected-path or approval flow
- Plaintext credential exposure in output, logs, or committed files
- Command injection, path traversal, or unsafe quoting in the scripts

Out of scope:

- Vulnerabilities in the AI tools this repository integrates with — report those upstream
- Findings that require the attacker to already hold write access to the repository
- Operator social-engineering scenarios

## Supported versions

Reference implementation, maintained on a best-effort basis. Only the `main`
branch is supported; there are no maintained release branches and no security
backports to older commits.

## What this policy does not promise

There is no SLA and no bug bounty. Reports are handled as time allows, and a fix
may land as an ordinary commit rather than a coordinated release.
