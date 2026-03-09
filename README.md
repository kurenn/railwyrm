# Railwyrm 🐉

Railwyrm is a Ruby CLI that bootstraps Rails apps with an opinionated default stack and an interactive feature wizard.

## Product Focus

- Deterministic Rails app generation
- Interactive wizard for auth/features
- Reproducible defaults for local development

See [VISION.md](VISION.md) for broader product direction.

## Default Stack

Every generated app includes:

- PostgreSQL (`rails new --database=postgresql`)
- Tailwind CSS (`rails new --css=tailwind` + `./bin/rails tailwindcss:install`)
- RSpec (`gem "rspec-rails"` + `bin/rails generate rspec:install`)
- Dotenv (`gem "dotenv-rails"` in development/test)
- Ruby LSP (`gem "ruby-lsp", require: false` in development)
- Devise (`gem "devise"` + install + user generation by default)
- Active Storage (`bin/rails active_storage:install`)
- ActionText (`bin/rails action_text:install`)
- Untitled UI (`gem "untitled_ui"` + installer)
- Claude on Rails (`gem "claude-on-rails"` + swarm generator)

## Wizard Features

During `railwyrm new`, the wizard can configure:

- Devise user generation (on/off)
- Devise optional modules:
  - `confirmable`
  - `lockable`
  - `timeoutable`
  - `trackable`
  - `magic_link` (via `devise-passwordless`)
- Devise sign-in layout:
  - `simple_minimal`
  - `card_combined`
  - `split_mockup_quote`

Magic-link behavior:

- Installs `devise-passwordless`
- Adds passwordless sign-in routes and UI
- Enables `Devise.paranoid = true`
- Auto-enables `trackable`
- Configures development mail delivery to file output at `tmp/mails`
- Installs a plain-text magic-link template for copy/paste-friendly URLs in development

## Quick Start

```bash
cd /path/to/railwyrm
bundle install
bundle exec ruby exe/railwyrm new
```

Non-interactive example:

```bash
bundle exec ruby exe/railwyrm new my_app --interactive=false --path /tmp --devise_magic_link
```

Install features into an existing app:

```bash
bundle exec ruby exe/railwyrm feature list
bundle exec ruby exe/railwyrm feature install magic_link --app /path/to/existing_app
```

## CLI Commands

```bash
bundle exec ruby exe/railwyrm new [APP_NAME]
bundle exec ruby exe/railwyrm feature list
bundle exec ruby exe/railwyrm feature install FEATURE [FEATURE ...] --app /path/to/app
bundle exec ruby exe/railwyrm serve
bundle exec ruby exe/railwyrm doctor
bundle exec ruby exe/railwyrm version
```

Common flags:

- `--no-banner` hide mascot/banner
- `--verbose` stream command output
- `--dry_run` print commands without executing
- `--sign_in_layout` choose auth page layout
- `--skip_devise_user` skip Devise model generation
- `--devise_confirmable` enable Devise confirmable
- `--devise_lockable` enable Devise lockable
- `--devise_timeoutable` enable Devise timeoutable
- `--devise_trackable` enable Devise trackable
- `--devise_magic_link` enable magic-link sign-in

Feature install options:

- `--app` path to the existing Rails app
- `--devise_user_model` Devise model name (default `User`)
- `--dry_run` show commands without executing
- `--verbose` stream command output

Installable features:

- `confirmable`
- `lockable`
- `timeoutable`
- `trackable`
- `magic_link` (automatically installs `trackable`)

## Development

Run tests:

```bash
bundle exec rspec
```

## Project Layout

- `exe/railwyrm` CLI entrypoint
- `lib/railwyrm/cli.rb` Thor commands
- `lib/railwyrm/generator.rb` generation workflow
- `lib/railwyrm/rails_blueprint.rb` stack defaults and setup commands
- `lib/railwyrm/templates/devise/*` auth templates
- `AGENTS.md` Codex repo instructions
