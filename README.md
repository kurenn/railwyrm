# Railwyrm 🐉

Railwyrm is an epic, colorful, interactive CLI for forging new Rails apps with a production-friendly default stack.
It is inspired by the feel of Claude CLI, and it can also run as a web server so apps can be created from a browser/API.

Mascot: **Emberclaw**, the forge-dragon.

## Why Railwyrm

- Interactive wizard for fast app setup
- Colorized terminal output, icons, and animated step feedback
- Opinionated Rails bootstrap defaults for modern apps
- Web/API mode for remote app creation workflows
- Built as a Ruby gem-style CLI project

## Default Rails Stack

Every generated app includes:

- Tailwind CSS (`rails new --css=tailwind` + `./bin/rails tailwindcss:install`)
- PostgreSQL (`rails new --database=postgresql`)
- RSpec (`gem "rspec-rails"` + `bin/rails generate rspec:install`)
- Devise sessions (`gem "devise"` + `bin/rails generate devise:install` + `bin/rails generate devise User`)
- Selectable Devise sign-in layouts (generated with Untitled UI view components, no social login buttons):
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
cd /Users/abrahamkuri/workspace/workspace/railwyrm
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
bundle exec ruby exe/railwyrm new my_new_app --interactive=false --path /Users/abrahamkuri/workspace/workspace

# choose a layout non-interactively
bundle exec ruby exe/railwyrm new my_new_app --interactive=false --sign_in_layout split_mockup_quote
```

## CLI Commands

```bash
bundle exec ruby exe/railwyrm new [APP_NAME]
bundle exec ruby exe/railwyrm serve --host 0.0.0.0 --port 4567 --workspace /Users/abrahamkuri/workspace/workspace
bundle exec ruby exe/railwyrm doctor
bundle exec ruby exe/railwyrm version
```

Common flags:

- `--no-banner` hide mascot/banner
- `--verbose` show underlying command output
- `--dry_run` print commands without executing
- `--sign_in_layout` choose auth page layout (`simple_minimal`, `card_combined`, `split_mockup_quote`)

## Web Forge Mode

Start the server:

```bash
bundle exec ruby exe/railwyrm serve --workspace /Users/abrahamkuri/workspace/workspace
```

Then open:

- [http://localhost:4567](http://localhost:4567)

API endpoints:

- `GET /health`
- `POST /api/apps` with JSON payload:

```json
{
  "name": "my_web_app",
  "workspace": "/Users/abrahamkuri/workspace/workspace",
  "devise_user_model": "User",
  "sign_in_layout": "card_combined"
}
```

- `GET /api/jobs/:id`

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
- `lib/railwyrm/server.rb` web/API mode
- `.codex/skills/*` project-local Codex skills
- `AGENTS.md` Codex-focused repo instructions

## Codex Optimization

This repo includes:

- `AGENTS.md` with high-signal workflow guidance for Codex
- Local skills for Ruby CLI and Rails kickstart stack maintenance:
  - `.codex/skills/ruby-cli-implementation/SKILL.md`
  - `.codex/skills/rails-kickstart-stack/SKILL.md`

These help Codex quickly make consistent, testable changes without rediscovering conventions.
