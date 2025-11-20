# Contributing

Thanks for wanting to contribute! This document explains how to contribute to this repository, the commit message standard we follow, and quick local checks to run before opening a Pull Request (PR).

**Quick checklist**

- Fork the repository and create a feature branch from `development`.
- Write clear, focused commits and follow the commit message convention below.
- Open a PR against the `development` branch with a clear description and link to any related issue.

**Branching**

- Create branches from `development`.
- Use descriptive branch names, for example:
  - `feat/login-fix`
  - `fix/entrypoint-cleanup`
  - `chore/update-readme`

**Commit messages**

We use the Conventional Commits style. Format your commit messages as:

```
<type>(<scope>): <short summary>

<body> (optional, more detailed description)
```

Common `type` values:
- `feat`: a new feature
- `fix`: a bug fix
- `docs`: documentation only changes
- `chore`: build or tooling changes
- `refactor`: code change that neither fixes a bug nor adds a feature
- `test`: adding or fixing tests
- `ci`: changes to CI configuration

Examples:
- `feat(logging): add per-map human-readable logs`
- `fix(entrypoint): remove persisted copy of server_raw.log on restart`

Keep the subject line <= 72 characters where possible. Include a more complete description in the body when the change is not trivial.

**Pull Requests**

- Open PRs against the `development` branch.
- Use a descriptive title and explain the motivation and what was changed.
- Reference related issues (e.g., `Closes #123`) when applicable.
- Ensure all checks pass (CI, linters) before requesting review.
- Keep PRs small and focused — easier to review and faster to merge.

**Code style & checks**

- Follow consistent formatting and naming conventions.
- Keep changes small and focused; prefer multiple small PRs over one large PR.
- Document how to validate your changes in the PR description.

**Tests & CI**

- Include test instructions in your PR when applicable.
- Keep CI configuration changes minimal and well documented.

**License & Contributor Agreement**

By submitting a Pull Request you agree that your contributions will be licensed under this repository's license (see `LICENSE`). If a separate contributor agreement is required it will be added to the repo.