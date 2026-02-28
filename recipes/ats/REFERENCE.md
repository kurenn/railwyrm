# ATS Reference Recipe

This recipe is the Railwyrm reference implementation for recipe-driven app expansion.

## Acceptance Contract

- Recipe validates with `railwyrm recipes validate recipes/ats/recipe.yml`
- UI baseline uses `untitled_ui` components
- Background jobs module uses Solid Queue (`solid_queue`)
- Recipe plan is deterministic and stable:
  - first command: `bin/rails generate pundit:install`
  - last command: `bin/rails db:migrate`
- Recipe can run in preview mode without side effects:
  - `railwyrm recipes apply recipes/ats/recipe.yml --workspace <path> --dry_run`
- Recipe apply runs quality gates from `quality_gates.required_commands`
- Referenced assets exist for:
  - `ui_overlays.copies[*].from`
  - `seed_data.file`
  - `ai_assets.agents`
  - `ai_assets.skills`
  - `ai_assets.prompts`
  - `ai_assets.playbooks`

## Canonical Flow

1. Generate a base app with Railwyrm.
2. Validate ATS recipe.
3. Plan ATS recipe command sequence.
4. Apply in `--dry_run`.
5. Apply for real after review.

## Notes

- This reference package is intentionally explicit and deterministic.
- AI assets are included as scaffolding for future feature workflows.
