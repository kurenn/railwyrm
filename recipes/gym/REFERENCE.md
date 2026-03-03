# Gym Draft Recipe

This recipe is a draft baseline for a gym management app in Railwyrm.

## Draft Contract

- Recipe validates with `railwyrm recipes validate recipes/gym/recipe.yml`
- UI baseline uses Untitled UI components and shared `dashboard_05` shell
- Background jobs module uses Solid Queue (`solid_queue`)
- Plan/apply flow remains deterministic and supports `--dry_run`
- Recipe overlays provide starter dashboard/member/visit/class views and docs
- AI assets are present for future gym-specific expert workflows

## Intended MVP Outcomes

- Staff can create and manage members
- Staff can track check-ins/check-outs (visits)
- Teams can manage class sessions and bookings
- Managers can review basic attendance and membership metrics

## Current Status

- `status: draft`
- Designed to be incrementally expanded to reference quality (tests + full workflows)
