---
name: rails-kickstart-stack
description: Maintain the Rails bootstrapping blueprint and install pipeline for newly generated apps. Use when changing default gems, Rails generator flags, post-bundle install commands, or feature defaults (Tailwind, PG, RSpec, Devise, ActiveStorage, ActionText, Untitled UI, Claude on Rails).
---

# Rails Kickstart Stack

## Canonical defaults

Generated apps must include:

- Tailwind via `rails new --css=tailwind`
- PostgreSQL via `rails new --database=postgresql`
- RSpec via `gem "rspec-rails"` and `bin/rails generate rspec:install`
- Devise sessions via `gem "devise"`, `bin/rails generate devise:install`, and model generation
- Active Storage install
- ActionText install
- `gem "untitled_ui", github: "coba-ai/untitled.ui", branch: "main"`
- `gem "claude-on-rails"` and `bin/rails generate claude_on_rails:swarm`

## Change workflow

1. Update stack definition in `lib/railwyrm/rails_blueprint.rb`.
2. Keep orchestration in `lib/railwyrm/generator.rb`.
3. Ensure dry-run remains side-effect free.
4. Update tests:
- `spec/railwyrm/rails_blueprint_spec.rb`
- `spec/railwyrm/generator_spec.rb`
5. Update docs in `README.md` to match defaults exactly.

## Implementation notes

- Prefer one place for stack constants (`RailsBlueprint`).
- Keep command order stable so generated apps are reproducible.
- Add optional features behind explicit config flags; keep defaults opinionated.
