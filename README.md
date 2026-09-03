# Railwyrm 🐉

Railwyrm is a Ruby CLI that bootstraps Rails apps with an opinionated default stack and an interactive feature wizard.

Project page: [docs/index.html](docs/index.html) (Tailwind CSS / GitHub Pages-ready)

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
- GitHub Actions CI (`.github/workflows/ci.yml` running RSpec, RuboCop, and Brakeman)
- Devise (`gem "devise"` + install + user generation by default)
- Active Storage (`bin/rails active_storage:install`)
- ActionText (`bin/rails action_text:install`)

Rails compatibility behavior:

- Railwyrm targets Ruby `3.4` for generated apps: `.ruby-version` gets `3.4.0`, and the Gemfile gets
  `ruby "~> 3.4.0"` so any 3.4.x patch release can bundle.
- Railwyrm generates with a Rails version it chooses rather than whatever happens to be installed:
  it runs `rails _8.1.3.1_ new`, so the Gemfile it produces is already correct instead of being
  rewritten afterwards. Install it with `gem install rails -v 8.1.3.1`; `railwyrm doctor` checks for it.
- Override with `--rails_version 8.0.3` if you need an older one.

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

CI behavior:

- Generates `.github/workflows/ci.yml` by default for new apps
- Provides `railwyrm feature install ci --app /path/to/app` for existing apps
- Workflow runs database prep, RSpec, RuboCop, and Brakeman on push/pull_request
- Generator normalizes default Bullet/Devise config formatting to keep RuboCop green in fresh apps

Quality feature behavior:

- Provides `railwyrm feature install quality --app /path/to/app` for existing apps
- Automatically installs dependency `ci` (workflow setup) when missing
- Ensures `brakeman`, `rubocop`, `rubocop-rails`, and `bullet` gems are present
- Injects Bullet development config (`Bullet.enable`, alerts, and Rails logger hooks)

## Install

```bash
git clone https://github.com/kurenn/railwyrm
cd railwyrm
./install.sh
```

That builds the gem and installs it for the current user, putting `railwyrm` in
`~/.local/bin` (override with `RAILWYRM_BIN_DIR`, or set
`RAILWYRM_INSTALL_SCOPE=system` to install system-wide). Add the bin directory to
your `PATH` if it isn't already, then:

```bash
railwyrm doctor
```

`doctor` checks for Ruby, Bundler, git, and the exact Rails version Railwyrm
generates with — install that one with `gem install rails -v 8.1.3.1`.

## Quick Start

```bash
railwyrm new
```

Non-interactive example:

```bash
railwyrm new my_app --interactive=false --path /tmp --devise_magic_link
```

Install features into an existing app:

```bash
railwyrm feature list
railwyrm feature status --app /path/to/existing_app
railwyrm feature sync --app /path/to/existing_app
railwyrm feature install magic_link --app /path/to/existing_app
railwyrm feature install ci --app /path/to/existing_app
railwyrm feature install quality --app /path/to/existing_app
```

To run from a clone without installing, prefix any command with
`bundle exec ruby exe/railwyrm` instead of `railwyrm`.

Feature state tracking:

- Railwyrm records installed features in `.railwyrm/features.yml` inside each generated app.
- `feature install` uses tracked state plus app detection to skip already-installed features safely.
- `feature status` shows `installed`, `tracked_only`, and `detected_only` feature sets for diagnostics.
- `feature sync` rebuilds `.railwyrm/features.yml` from detected app state.

## CLI Commands

```bash
railwyrm new [APP_NAME]
railwyrm feature list
railwyrm feature status --app /path/to/app
railwyrm feature sync --app /path/to/app
railwyrm feature install FEATURE [FEATURE ...] --app /path/to/app
railwyrm serve
railwyrm doctor
railwyrm version
```

Common flags:

- `--no-banner` hide mascot/banner
- `--verbose` stream command output
- `--dry_run` print commands without executing
- `--skip_devise_user` skip Devise model generation
- `--devise_confirmable` enable Devise confirmable
- `--devise_lockable` enable Devise lockable
- `--devise_timeoutable` enable Devise timeoutable
- `--devise_trackable` enable Devise trackable
- `--devise_magic_link` enable magic-link sign-in
- `--devise_passkeys` enable passkeys sign-in (WebAuthn)
- `--rails_version` Rails version used to generate the app (default `8.1.3.1`)

Server mode (`railwyrm serve`):

- Binds `0.0.0.0` by default; pass `--host 127.0.0.1` to keep it local.
- `POST /api/apps` runs `rails new` and `bundle install` on the host, so only serve on networks you trust.
- Generation is confined to `--workspace`; paths outside it are rejected with `422`.

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
- `ci`
- `quality` (automatically installs `ci`)

## Development

Run tests:

```bash
bundle exec rspec
```

The end-to-end spec generates a real Rails app, so it is excluded by default. It
needs PostgreSQL running and the Rails version from `railwyrm doctor`:

```bash
RUN_E2E=1 bundle exec rspec spec/e2e
```

CI runs it nightly, and builds and installs the gem on every push so a packaging
mistake cannot reach users.

## Releasing

1. Bump `Railwyrm::VERSION` in `lib/railwyrm/version.rb`.
2. `bundle exec rspec` and `RUN_E2E=1 bundle exec rspec spec/e2e`.
3. Merge to `main` and confirm the `Built gem is usable` job passes.
4. Tag it: `git tag v$(ruby -Ilib -rrailwyrm/version -e 'print Railwyrm::VERSION') && git push --tags`.
5. Publish if desired: `gem build railwyrm.gemspec && gem push railwyrm-*.gem`.

## Project Layout

- `exe/railwyrm` CLI entrypoint
- `lib/railwyrm/cli.rb` Thor commands
- `lib/railwyrm/generator.rb` new-app generation workflow
- `lib/railwyrm/feature_installer.rb` feature installs for existing apps
- `lib/railwyrm/app_patcher.rb` the in-place edits both of those share
- `lib/railwyrm/rails_blueprint.rb` stack defaults and setup commands
- `spec/e2e/` generates a real Rails app; run with `RUN_E2E=1 bundle exec rspec spec/e2e`
- `lib/railwyrm/templates/devise/{passkeys,passwordless}` magic-link and passkey auth templates
- `AGENTS.md` Codex repo instructions
