# Contributing to macstrap

Thanks for helping improve macstrap. Contributions should preserve its central
properties: reproducibility, idempotence, reversibility, and a public repository
free of personal information.

## Before you start

- Search existing issues before opening a new one.
- Report vulnerabilities privately according to [SECURITY.md](SECURITY.md).
- Read the relevant guide in `docs/` before changing a script or managed file.
- Never commit a real name, email address, GitHub handle, hostname, internal URL,
  token, key, or other machine-specific value. Follow the privacy table in the
  README.

## Development workflow

1. Fork the repository and create a focused branch from `main`.
2. Make the smallest coherent change and keep macOS-specific behavior explicit.
3. Preserve backups and refusal checks. Do not turn a reversible operation into
   a destructive one.
4. Update the matching guide under `docs/` when behavior, ownership, ordering,
   or a prerequisite changes.
5. Add or update coverage in `scripts/test.sh` for script behavior.

## Validate the change

Run the repository test suite:

```bash
scripts/test.sh
```

For changes that affect an installed machine, also run the read-only health
check after exercising the change in an appropriate test environment:

```bash
scripts/doctor.sh
```

Do not test bootstrap or defaults changes on someone else's workstation. State
the macOS version and hardware architecture used for manual validation.

## Pull requests

Explain the problem, the chosen behavior, validation performed, and how the
change can be reversed. Call out changes to packages, shell startup order,
symlinks, macOS defaults, identities, or credentials. Keep unrelated cleanup in
separate pull requests.

By participating, you agree to follow the
[Code of Conduct](CODE_OF_CONDUCT.md).
