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
  - `bin/rails generate claude_on_rails:swarm --force`
- Optional magic-link sign-in:
  - `gem "devise-passwordless"`
  - `bin/rails generate devise:passwordless:install --force`
  - Development mail delivery configured to file output at `tmp/mails`
  - Plain-text magic-link mail template is installed for copy/paste-friendly links in development

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

Interactive wizard note:

- If `--recipe` is not provided, the wizard asks whether to apply a recipe and shows the currently available recipes for selection.
- If Devise user generation is enabled, the wizard asks whether to enable Devise `confirmable`, `lockable`, `timeoutable`, `trackable`, and magic-link sign-in.
- If magic-link sign-in is enabled, Railwyrm automatically enables Devise `trackable` and prints an info message.

Run non-interactive mode:

```bash
bundle exec ruby exe/railwyrm new my_new_app --interactive=false --path /path/to/workspace

# choose a layout non-interactively
bundle exec ruby exe/railwyrm new my_new_app --interactive=false --sign_in_layout split_mockup_quote
```

## CLI Commands

```bash
bundle exec ruby exe/railwyrm new [APP_NAME]
bundle exec ruby exe/railwyrm new [APP_NAME] --recipe ats
bundle exec ruby exe/railwyrm recipes list
bundle exec ruby exe/railwyrm recipes profiles
bundle exec ruby exe/railwyrm recipes show ats
bundle exec ruby exe/railwyrm recipes validate [RECIPE_PATH]
bundle exec ruby exe/railwyrm recipes plan [RECIPE_PATH] --workspace /path/to/app
bundle exec ruby exe/railwyrm recipes plan [RECIPE_PATH] --workspace /path/to/app --with background_jobs --deploy render
bundle exec ruby exe/railwyrm recipes apply [RECIPE_PATH] --workspace /path/to/app
bundle exec ruby exe/railwyrm recipes apply [RECIPE_PATH] --workspace /path/to/app --with background_jobs --deploy render
bundle exec ruby exe/railwyrm doctor
bundle exec ruby exe/railwyrm version
```

Common flags:

- `--no-banner` hide mascot/banner
- `--verbose` show underlying command output
- `--dry_run` print commands without executing
- `--sign_in_layout` choose auth page layout (`simple_minimal`, `card_combined`, `split_mockup_quote`)
- `--devise_confirmable` enable Devise `confirmable` for the generated user model
- `--devise_lockable` enable Devise `lockable` for the generated user model
- `--devise_timeoutable` enable Devise `timeoutable` for the generated user model
- `--devise_trackable` enable Devise `trackable` for the generated user model
- `--devise_magic_link` enable Devise magic-link sign-in via email (`devise-passwordless`)
- `--recipe` apply a recipe by name (e.g. `ats`) or `recipe.yml` path during `new`
- `--with` enable optional recipe modules (for example `background_jobs`)
- `--deploy` apply recipe deploy preset (for example `render`, `fly`)

## Development

Run tests:

```bash
bundle exec rspec
```

Run ATS end-to-end generation test (opt-in):

```bash
RUN_E2E=1 bundle exec rspec spec/e2e/ats_generation_spec.rb
```

CI note:

- GitHub Actions runs ATS E2E on pull requests and `main` pushes in addition to the regular spec suite.

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

## Recipes

Recipe specs and prompt-driven harnesses live under `recipes/`.

- ATS reference recipe spec: `recipes/ats/recipe.yml`
- ATS reference contract: `recipes/ats/REFERENCE.md`
- ATS test prompt: `recipes/ats/prompt.md`
- Gym reference recipe spec: `recipes/gym/recipe.yml`
- Gym reference contract: `recipes/gym/REFERENCE.md`
- Gym test prompt: `recipes/gym/prompt.md`

ATS is the reference implementation for recipe contract, plan/apply flow, and
asset structure.

Recipe standards:

- UI assets in recipes should be implemented with `untitled_ui` components.
- Background jobs modules should use Solid Queue (`solid_queue`).
- Shared UI profiles live under `recipes/_shared/ui_profiles/*` and can be enabled per recipe via `ui_profile`.

### Recipe Schema v0

`railwyrm recipes validate` enforces a strict top-level `recipe.yml` contract.

Required top-level keys:

- `id`
- `name`
- `version`
- `status`
- `description`
- `base_stack`
- `inputs`
- `roles`
- `gems`
- `data_model`
- `scaffolding_plan`
- `ui_overlays`
- `routes`
- `authorization`
- `seed_data`
- `quality_gates`
- `ai_assets`

Optional top-level keys:

- `ui_profile`
- `module_setup`
- `deploy`

The validator also enforces key nested structures for deterministic recipes,
including `base_stack.requires`, `scaffolding_plan.commands`, and
`ai_assets` (`agents`, `skills`, `prompts`, `playbooks`).
When `ui_profile` is set, validation also checks that the shared profile exists
under `recipes/_shared/ui_profiles` and has the required overlay directories.

### Deterministic Recipe Execution

- `railwyrm recipes plan` prints the exact command order from `scaffolding_plan.commands`
- `railwyrm recipes apply` runs those commands in that same order
- `apply` also executes recipe file operations:
  - injects unauthenticated root (`/`) redirect to `/users/sign_in` unless the recipe defines a public root route
  - auto-copies shared UI profile overlays when `ui_profile` is configured
  - copies `ui_overlays.copies[*]` sources into target app paths
  - installs `seed_data.file` into `db/seeds/<recipe>.seeds.rb` and loads it from `db/seeds.rb`
  - wires `routes` into `config/routes.rb` and creates missing controller/policy stubs
- ATS overlays also install starter models, policy classes, and hardening migrations
- required recipe gems are inserted into Gemfile and installed before scaffold commands
- `apply` runs `quality_gates.required_commands` after scaffolding and asset install
- `apply` can install module gems and setup commands with `--with`
- `apply` can install deploy preset files and run smoke commands with `--deploy`
- Use `--dry_run` with `apply` to preview command execution without running commands

### Recipe Discovery

- `railwyrm recipes list` shows available recipes under `recipes/*/recipe.yml`
- `railwyrm recipes profiles` shows shared UI profiles under `recipes/_shared/ui_profiles/*`
- `railwyrm recipes show <recipe>` shows metadata, modules, scaffold command list, and quality gates

### ATS Reference Flow

1. Generate a base app with `railwyrm new` (or directly with recipe):
   - `bundle exec ruby exe/railwyrm new ats_app --interactive=false --path /tmp --recipe ats`
2. Validate ATS recipe:
   - `bundle exec ruby exe/railwyrm recipes validate recipes/ats/recipe.yml`
3. Preview ATS command plan:
   - `bundle exec ruby exe/railwyrm recipes plan recipes/ats/recipe.yml --workspace /path/to/app`
4. Dry run apply:
   - `bundle exec ruby exe/railwyrm recipes apply recipes/ats/recipe.yml --workspace /path/to/app --dry_run`
5. Apply for real after review:
   - `bundle exec ruby exe/railwyrm recipes apply recipes/ats/recipe.yml --workspace /path/to/app`
