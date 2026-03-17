# Railwyrm

> Bootstrap Rails apps that are production-minded on day one, and AI-accelerated when you want it.

## Motivation

Most Rails projects lose time in the same first weeks:

- repeating the same setup by hand
- debating defaults every single time
- fixing quality/security tooling after the app already grew
- adding auth and delivery workflows too late

Railwyrm exists to remove that early drag.  
It gives teams a deterministic starting point, with an interactive feature wizard so you can opt into stronger auth and delivery capabilities without rebuilding your stack each time.

## What Railwyrm Is

Railwyrm is a Ruby CLI that generates new Rails applications with:

- an opinionated default stack
- reproducible generation flow
- optional interactive wizard
- post-generation feature installation for existing apps

Core idea: **reliable baseline first, AI-native acceleration second**.

## How The Script Works

When you run `railwyrm new`, Railwyrm:

1. Creates a Rails app with PostgreSQL + Tailwind.
2. Installs baseline gems and tooling.
3. Runs framework setup steps (Devise, Active Storage, ActionText, Untitled UI, RSpec, CI, etc.).
4. Applies selected auth features from the wizard.
5. Writes feature state to `.railwyrm/features.yml`.

The flow is deterministic and script-friendly:

- interactive mode for local product work
- non-interactive mode for CI/scripts (`--interactive=false`)
- `--dry_run` support for safe planning without mutations

## Usage

### Create a new app

```bash
bundle exec ruby exe/railwyrm new my_app
```

### Non-interactive mode

```bash
bundle exec ruby exe/railwyrm new my_app \
  --interactive=false \
  --path /tmp \
  --devise_magic_link \
  --devise_passkeys
```

### Install features into an existing app

```bash
bundle exec ruby exe/railwyrm feature list
bundle exec ruby exe/railwyrm feature status --app /path/to/app
bundle exec ruby exe/railwyrm feature install magic_link --app /path/to/app
bundle exec ruby exe/railwyrm feature install quality --app /path/to/app
bundle exec ruby exe/railwyrm feature sync --app /path/to/app
```

## What You Get By Default

- PostgreSQL + Tailwind CSS
- RSpec + CI workflow
- Devise auth baseline
- Active Storage + ActionText
- Untitled UI integration
- Claude on Rails swarm bootstrap
- Dev quality/security stack:
  - RuboCop
  - Brakeman
  - Bullet
  - Ruby LSP
  - Dotenv

## Feature Wizard (Current)

- Devise optional modules:
  - `confirmable`
  - `lockable`
  - `timeoutable`
  - `trackable`
- Auth extensions:
  - `magic_link` (passwordless email sign-in)
  - `passkeys` (WebAuthn via devise-webauthn)
- Sign-in layout packs:
  - `simple_minimal`
  - `card_combined`
  - `split_mockup_quote`

## Vision

Railwyrm aims to be the place where teams can kickstart serious Rails products with:

- proven base architecture
- deterministic setup
- recipe-level domain acceleration
- AI assets that make feature delivery faster with Claude or Codex

From `VISION.md`:

- Deterministic by default
- AI is optional but first-class
- Preview before apply
- Safety by design
- Versioned evolution

## Why This Matters

Railwyrm is less about “generate code quickly,” and more about:

- reducing avoidable setup mistakes
- improving first-week delivery speed
- making every new app start from a production-minded baseline
- keeping generated output auditable and maintainable

If you are building repeatedly with Rails, Railwyrm turns setup from a recurring project into a solved problem.

## Command Reference

```bash
bundle exec ruby exe/railwyrm new [APP_NAME]
bundle exec ruby exe/railwyrm feature list
bundle exec ruby exe/railwyrm feature status --app /path/to/app
bundle exec ruby exe/railwyrm feature sync --app /path/to/app
bundle exec ruby exe/railwyrm feature install FEATURE [FEATURE ...] --app /path/to/app
bundle exec ruby exe/railwyrm serve
bundle exec ruby exe/railwyrm doctor
bundle exec ruby exe/railwyrm version
```

## Related Docs

- [README.md](../README.md)
- [VISION.md](../VISION.md)
- [AGENTS.md](../AGENTS.md)
