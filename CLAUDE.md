# CLAUDE.md

## Project context

Railwyrm is a Ruby CLI + web API that bootstraps Rails apps with an opinionated default stack.
Favor deterministic behavior, reproducible generation, and script-friendly non-interactive flows.

## Canonical product reference

- Read `VISION.md` before making roadmap or feature-workflow decisions.
- Treat `VISION.md` as the source of truth for scope, principles, metrics, and the generated-app
  and feature contracts.
- If a request conflicts with `VISION.md`, surface the conflict and propose either:
  - updating `VISION.md`, or
  - approving an explicit one-off exception.

## Engineering conventions

- Keep `--dry_run` safe (no file writes).
- Prefer stack behavior changes in `lib/railwyrm/rails_blueprint.rb` (gems and setup commands)
  and `lib/railwyrm/app_patcher.rb` (edits to an existing app).
- `Generator` and `FeatureInstaller` orchestrate; they share `AppPatcher` rather than each
  carrying their own copy. Fix patching bugs there, once.
- Run `bundle exec rspec` after changes under `lib/`.
