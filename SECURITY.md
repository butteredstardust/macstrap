# Security Policy

macstrap installs packages, manages dotfiles, changes shell startup, and applies
macOS settings. A defect can affect a developer's whole workstation, so please
report security problems privately.

## Supported versions

Security fixes are applied to the latest revision of `main`. There are no
maintained release branches.

## Reporting a vulnerability

Do not open a public issue for a suspected vulnerability. Contact the
maintainer privately using the contact methods on the
[maintainer's GitHub profile](https://github.com/butteredstardust). If no private
contact method is available, open a public issue asking for a private contact
channel without including vulnerability details.

Include the affected revision and macOS version, minimal reproduction steps,
the files or commands involved, impact, and a suggested mitigation if known.
Remove names, email addresses, tokens, keys, hostnames, internal URLs, and other
machine-specific information from logs and screenshots.

You should receive an acknowledgment within 10 business days. The maintainer
will validate the report, coordinate a remediation and disclosure timeline, and
credit the reporter if requested.

## Scope

In scope are vulnerabilities introduced by `bootstrap.sh`, scripts under
`scripts/`, managed dotfiles, Brewfiles, editor configuration, macOS defaults,
and the documented installation workflow. Examples include unsafe shell
evaluation, command injection, insecure downloads, credential exposure,
permission errors, and destructive behavior that violates documented backups.

Vulnerabilities solely in Homebrew, an installed package, or another upstream
project should also be reported upstream. Notify macstrap if a pinned or
recommended configuration remains affected.

## Safe research

Test only on a machine you own or are authorized to use. Prefer a disposable
macOS VM or test account for bootstrap changes. Do not collect credentials or
personal data, and stop if testing could damage unrelated user files.
