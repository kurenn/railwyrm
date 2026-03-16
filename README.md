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
- Brakeman (`gem "brakeman", require: false` in development/test)
- RuboCop (`gem "rubocop"` + `gem "rubocop-rails"` in development/test)
- Bullet (`gem "bullet"` in development + auto-configured in `config/environments/development.rb`)
- Devise (`gem "devise"` + install + user generation by default)
- Active Storage (`bin/rails active_storage:install`)
- ActionText (`bin/rails action_text:install`)
- Untitled UI (`gem "untitled_ui"` + installer)
- Claude on Rails (`gem "claude-on-rails", github: "kurenn/claude-on-rails", branch: "main"` + swarm generator)

## Wizard Features

During `railwyrm new`, the wizard can configure:

- Devise user generation (on/off)
- Devise optional modules:
  - `confirmable`
  - `lockable`
  - `timeoutable`
  - `trackable`
  - `magic_link` (via `devise-passwordless`)
  - `passkeys` (via `devise-webauthn`)
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

Passkeys behavior:

- Installs `devise-webauthn`
- Runs `bin/rails generate devise:webauthn:install --force`
- Adds `:passkey_authenticatable` to the Devise model
- Configures `config/initializers/webauthn.rb` defaults for `rp_name` (generated app name), `rp_id`, and localhost origins
- Populates `.env.example` with `WEBAUTHN_RP_NAME`, `WEBAUTHN_RP_ID`, and `WEBAUTHN_ALLOWED_ORIGINS`
- Ensures WebAuthn JavaScript is loaded as an ES module
- Adds passkey sign-in button on Devise sign-in page
- Redirects first sign-in users (without passkeys) to passkey enrollment
- Runs migrations for the generated WebAuthn tables

Passkeys production checklist:

1. Run the app under HTTPS in production.
2. Set `WEBAUTHN_RP_ID` to your real domain (for example `app.example.com`).
3. Set `WEBAUTHN_ALLOWED_ORIGINS` to your exact HTTPS origin list (for example `https://app.example.com`).

Passkeys smoke test checklist (generated app):

1. Sign in with email/password and verify you are redirected to the passkey enrollment page on first sign-in.
2. Create a passkey and confirm the page no longer forces enrollment on next sign-in.
3. Sign out and use "Sign in with passkey" from the sign-in page to confirm passwordless passkey authentication works.

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
bundle exec ruby exe/railwyrm feature status --app /path/to/existing_app
bundle exec ruby exe/railwyrm feature sync --app /path/to/existing_app
bundle exec ruby exe/railwyrm feature install magic_link --app /path/to/existing_app
```

Feature state tracking:

- Railwyrm records installed features in `.railwyrm/features.yml` inside each generated app.
- `feature install` uses tracked state plus app detection to skip already-installed features safely.
- `feature status` shows `installed`, `tracked_only`, and `detected_only` feature sets for diagnostics.
- `feature sync` rebuilds `.railwyrm/features.yml` from detected app state.

## CLI Commands

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
- `--devise_passkeys` enable passkeys sign-in (WebAuthn)

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
- `passkeys`

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
