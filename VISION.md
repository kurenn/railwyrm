# Railwyrm Vision

## North Star

Railwyrm exists to help teams kickstart production-ready Rails applications and to expand
existing ones with the same defaults later. Generation is deterministic: the same inputs
produce the same app, and every step is inspectable before it runs.

## v1 Audience

- Solo founders shipping their first production app
- Small product teams that want a strong Rails baseline without rebuilding the same setup
- Teams that want their auth and quality tooling decided once, not re-litigated per project

## v1 Scope

- A deterministic `railwyrm new` that produces a running Rails app with auth, tests, styling, and CI
- A `railwyrm feature` family that installs the same capabilities into apps generated earlier
- Feature state tracked in the generated app, reconcilable against what the app actually contains
- Non-interactive/script mode as a first-class path, with the interactive wizard optional

## v1 Non-Goals

- Supporting frameworks or languages outside Rails
- One-off custom enterprise workflows in core
- Generation that cannot be previewed or reproduced
- Unversioned changes to generated output that silently break existing apps

## Product Principles

- Deterministic by default: generation must be reproducible
- Preview before apply: `--dry_run` must never write files
- Safety by design: execution must be constrained, validated, and auditable
- Idempotent features: installing a feature twice is a no-op, and a partial install can be repaired
- Versioned evolution: changes to generated output ship with explicit upgrade paths

## Success Metrics

- Time to first running app
- Generated app verification pass rate (`rspec`, routes, Zeitwerk, lint/security checks)
- Share of `feature install` runs that complete without manual repair
- Repeat usage across new projects

## Generated App Contract

Every app `railwyrm new` produces must ship with:

- PostgreSQL and Tailwind CSS, installed and working
- Devise authentication, with optional modules the wizard can enable
- RSpec, plus Active Storage and ActionText
- A quality baseline: Brakeman, RuboCop, Bullet
- A GitHub Actions CI workflow that runs the test suite, RuboCop, and Brakeman
- A `.railwyrm/features.yml` manifest recording what was installed

## Feature Contract

Every installable feature must:

- Detect its own presence from the app's real contents, not only from the manifest
- Be safe to install twice
- Declare its dependencies in `FeatureRegistry`
- Leave the app's test suite passing

## Operating Cadence

- Review this vision against the roadmap monthly
- Require new features to map to at least one product principle and one success metric
- Keep roadmap execution details in `ROADMAP.local.md`; keep this file stable as the product contract
