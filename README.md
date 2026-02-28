# Railwyrm 🐉

Railwyrm is an epic, colorful, interactive CLI for forging new Rails apps with a production-friendly default stack.
It is inspired by the feel of Claude CLI.

Mascot: **Emberclaw**, the forge-dragon.

## Why Railwyrm

- Interactive wizard for fast app setup
- Colorized terminal output, icons, and animated step feedback
- Opinionated Rails bootstrap defaults for modern apps
- Built as a Ruby gem-style CLI project

## Product Vision

Railwyrm's north star is to kickstart production-ready Rails apps and make feature expansion AI-native with recipe-specific expert assets.

- Reproducible base apps first
- AI-assisted feature delivery second
- Safe, versioned evolution over one-off generation

See [VISION.md](VISION.md) for scope, principles, metrics, and recipe contract.

## Default Rails Stack

Every generated app includes:

- Tailwind CSS (`rails new --css=tailwind` + `./bin/rails tailwindcss:install`)
- PostgreSQL (`rails new --database=postgresql`)
- RSpec (`gem "rspec-rails"` + `bin/rails generate rspec:install`)
- Devise sessions (`gem "devise"` + `bin/rails generate devise:install` + `bin/rails generate devise User`)
- Selectable Devise auth layouts (sessions, registrations, passwords, confirmations, unlocks) generated with Untitled UI view components and no social login buttons:
  - `simple_minimal`
  - `card_combined`
  - `split_mockup_quote`
- Active Storage (`bin/rails active_storage:install`)
- ActionText (`bin/rails action_text:install`)
- Untitled UI gem:
  - `gem "untitled_ui", github: "coba-ai/untitled.ui", branch: "main"`
  - `bin/rails generate untitled_ui:install`
- Claude on Rails gem:
  - `gem "claude-on-rails"`
  - `bin/rails generate claude_on_rails:swarm`

## Quick Start

```bash
cd /path/to/railwyrm
bundle install
```

## One-Command Installer

From the project root:

```bash
./install.sh
```

This builds and installs `railwyrm` globally for your user (default bin path: `~/.local/bin`).

Optional install modes:

```bash
# system-wide install (may require elevated privileges)
RAILWYRM_INSTALL_SCOPE=system ./install.sh

# custom user bin directory
RAILWYRM_BIN_DIR="$HOME/bin" ./install.sh
```

Installer note:

- `install.sh` uses `gem install --force`, so local updates are reinstalled even if the version is already present.

Run interactive mode:

```bash
bundle exec ruby exe/railwyrm new
```

Run non-interactive mode:

```bash
bundle exec ruby exe/railwyrm new my_new_app --interactive=false --path /path/to/workspace

# choose a layout non-interactively
bundle exec ruby exe/railwyrm new my_new_app --interactive=false --sign_in_layout split_mockup_quote
```

## CLI Commands

```bash
bundle exec ruby exe/railwyrm new [APP_NAME]
bundle exec ruby exe/railwyrm doctor
bundle exec ruby exe/railwyrm version
```

Common flags:

- `--no-banner` hide mascot/banner
- `--verbose` show underlying command output
- `--dry_run` print commands without executing
- `--sign_in_layout` choose auth page layout (`simple_minimal`, `card_combined`, `split_mockup_quote`)

## Development

Run tests:

```bash
bundle exec rspec
```

## Project Layout

- `exe/railwyrm` executable entrypoint
- `install.sh` one-command installer (build + gem install)
- `lib/railwyrm/cli.rb` Thor CLI commands
- `lib/railwyrm/generator.rb` Rails app creation workflow
- `lib/railwyrm/rails_blueprint.rb` default stack definition and setup steps
- `.codex/skills/*` project-local Codex skills
- `AGENTS.md` Codex-focused repo instructions

## Codex Optimization

This repo includes:

- `AGENTS.md` with high-signal workflow guidance for Codex
- Local skills for Ruby CLI and Rails kickstart stack maintenance:
  - `.codex/skills/ruby-cli-implementation/SKILL.md`
  - `.codex/skills/rails-kickstart-stack/SKILL.md`

These help Codex quickly make consistent, testable changes without rediscovering conventions.

## Recipe Drafts

Draft recipe specs and prompt-driven test harnesses live under `recipes/`.

- ATS recipe spec: `recipes/ats/recipe.yml`
- ATS test prompt: `recipes/ats/prompt.md`

These are currently design-time assets for planning and prompt testing before
native recipe execution is added to the CLI.
