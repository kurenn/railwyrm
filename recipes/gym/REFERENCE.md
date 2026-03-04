# Gym Reference Recipe

This recipe is the Gym Management reference implementation for Railwyrm recipe expansion.

## Acceptance Contract

- Recipe validates with `railwyrm recipes validate recipes/gym/recipe.yml`
- UI baseline uses `untitled_ui` components and shared shell profile `dashboard_05`
- Background jobs module uses Solid Queue (`solid_queue`)
- Recipe plan is deterministic and stable:
  - first command: `bin/rails generate pundit:install`
  - last command: `bin/rails db:migrate`
- Recipe can run in preview mode without side effects:
  - `railwyrm recipes apply recipes/gym/recipe.yml --workspace <path> --dry_run`
- Recipe apply wires route entries and baseline controllers/policies from recipe spec
- Recipe apply copies Gym starter models/controllers/policies/migrations/specs
- Recipe apply runs quality gates from `quality_gates.required_commands`
- Recipe modules can be enabled via `--with` and install module gems/setup deterministically
- Recipe deploy presets can be enabled via `--deploy` and run deploy smoke commands
- Generated app includes core gym workflows:
  - create/edit members
  - record visits/check-ins
  - create membership plans
  - create class sessions and manage class bookings
  - public schedule and membership request flow

## Canonical Flow

1. Generate a base app with Railwyrm.
2. Validate Gym recipe.
3. Plan Gym recipe command sequence.
4. Apply in `--dry_run`.
5. Apply for real after review.

## Notes

- This package is explicit and deterministic by default.
- AI assets are included as scaffolding for future gym-specific workflows.
