# AGENTS.md instructions for <repo-root>

## Project intent

Railwyrm is a Ruby CLI + web API that bootstraps Rails apps with an opinionated default stack.
Keep UX interactive, command flow deterministic, and generated output reproducible.

## Canonical product reference

- Treat `VISION.md` as the source of truth for product direction.
- When proposing roadmap items, recipe changes, or feature workflow behavior, align decisions to `VISION.md` (scope, principles, metrics, recipe contract).
- If a request conflicts with `VISION.md`, call out the conflict and propose a `VISION.md` update or an explicit exception.

## Skills

A skill is a local instruction package in a `SKILL.md` file.

### Available skills

- ruby-cli-implementation: Implement and maintain Thor-based Ruby CLI workflows, terminal UX, and command orchestration. (file: .codex/skills/ruby-cli-implementation/SKILL.md)
- rails-kickstart-stack: Maintain the Rails bootstrap blueprint and post-generation install pipeline for default gems/features. (file: .codex/skills/rails-kickstart-stack/SKILL.md)

### Skill trigger rules

- Use `ruby-cli-implementation` when editing command behavior, prompts, banner, terminal UX, or CLI architecture.
- Use `rails-kickstart-stack` when changing default Rails stack dependencies, setup commands, or generated app workflow.
- If both are relevant, use `rails-kickstart-stack` first (stack decisions), then `ruby-cli-implementation` (exposed CLI behavior).

## Working conventions

- Run `bundle exec rspec` after any change in `lib/`.
- Prefer adding/changing behavior in `lib/railwyrm/rails_blueprint.rb` and `lib/railwyrm/generator.rb` instead of scattering stack logic.
- Keep `--dry_run` behavior safe: never write files when dry-run is enabled.
- Keep interactive prompts optional; non-interactive mode must be script-friendly.
- For server mode, avoid blocking API responses indefinitely; use job status polling.

## Definition of done

- Tests pass (`bundle exec rspec`).
- README reflects changed CLI flags/commands.
- If stack defaults changed, update both `README.md` and specs in `spec/railwyrm/rails_blueprint_spec.rb`.
