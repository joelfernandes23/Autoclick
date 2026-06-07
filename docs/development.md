# Development Workflow

Use short-lived branches for changes and open pull requests back into `master`.
Keep direct pushes to `master` for repository-owner emergencies only.

## Branches

Start from an up-to-date `master`:

```sh
git switch master
git pull --ff-only origin master
git switch -c type/short-description
```

Use concise branch names such as `fix/click-interval`, `ci/release-preflight`, or `docs/development-workflow`.

## Commits

Prefer conventional commit prefixes so Release Please can prepare versioned release pull requests:

- `fix:` for bug fixes
- `feat:` for user-visible features
- `ci:` for workflow and release automation
- `docs:` for documentation-only changes
- `chore:` for maintenance that should not affect users

## Pull Requests

Use the project pull request format:

```md
WHAT

WHY

HOW
```

Wait for the required `Build` check before merging. Documentation-only changes use a fast CI path, while app and release changes run the macOS build and validation steps.
