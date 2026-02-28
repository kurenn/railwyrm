# Railwyrm Vision

## North Star

Railwyrm exists to help teams kickstart production-ready Rails applications and expand them with AI-native feature delivery. Every recipe should produce a reproducible base app first, then provide recipe-specific expert assets that make feature delivery faster with Claude or Codex.

## v1 Audience

- Solo founders shipping their first production app
- Small product teams that want a strong Rails baseline without rebuilding the same setup
- AI-assisted teams that want guided feature workflows, not open-ended prompt chaos

## v1 Scope

- Deliver deterministic recipe execution for flagship recipes, starting with `ats` as the reference implementation
- Ensure every generated app includes a ready-to-ship baseline (auth, roles, seeds, tests, deploy sanity)
- Provide per-recipe AI assets and workflows compatible with Claude and Codex
- Keep interactive CLI UX optional so non-interactive/script mode remains first-class

## v1 Non-Goals

- Supporting every framework or language outside Rails
- One-off custom enterprise workflows in core
- Opaque AI-only generation that cannot be previewed or reproduced
- Unversioned recipe changes that break existing generated apps

## Product Principles

- Deterministic by default: generation must be reproducible without AI
- AI is optional but first-class: API keys unlock additional capability, not core reliability
- Preview before apply: feature workflows should support plan and review prior to mutation
- Safety by design: execution must be constrained, validated, and auditable
- Versioned evolution: recipes and agent packs evolve with explicit versions and upgrade paths

## Success Metrics

- Time to first running app from a recipe
- Time to first shipped feature using recipe AI assets
- Generated app verification pass rate (`rspec`, routes, Zeitwerk, lint/security checks)
- Recipe adoption and repeat usage across new projects

## Recipe Contract

Each recipe must ship with:

- Deterministic scaffold and install flow
- Core domain schema, routes, and seed data
- Authentication and role baseline
- Responsive UI baseline with accessibility sanity checks
- Test suite and validation checks that pass on generation
- Deployment and observability baseline
- AI assets organized by convention (`agents/`, `skills/`, `prompts/`, `playbooks/`)

## Operating Cadence

- Review this vision monthly against roadmap milestones
- Require new major features to map to at least one product principle and one success metric
- Keep roadmap execution details in `ROADMAP.local.md`; keep this file stable as the product contract
