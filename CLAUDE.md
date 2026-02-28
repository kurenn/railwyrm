# CLAUDE.md

## Project context

Railwyrm is a Ruby CLI + web API that bootstraps Rails apps with an opinionated default stack.
Favor deterministic behavior, reproducible generation, and script-friendly non-interactive flows.

## Canonical product reference

- Read `VISION.md` before making roadmap, recipe, or feature-workflow decisions.
- Treat `VISION.md` as the source of truth for scope, principles, metrics, and recipe contract.
- If a request conflicts with `VISION.md`, surface the conflict and propose either:
  - updating `VISION.md`, or
  - approving an explicit one-off exception.

## Engineering conventions

- Keep `--dry_run` safe (no file writes).
- Prefer stack behavior changes in `lib/railwyrm/rails_blueprint.rb` and `lib/railwyrm/generator.rb`.
- Run `bundle exec rspec` after changes under `lib/`.
