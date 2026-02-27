---
name: ruby-cli-implementation
description: Build, refactor, or debug Thor-based Ruby CLI tools with interactive terminal UX, command orchestration, and test coverage. Use when tasks involve command options, prompts, colorful output, executable entrypoints, or CLI architecture in this repository.
---

# Ruby CLI Implementation

## Workflow

1. Read CLI surface first:
- Inspect `exe/railwyrm` and `lib/railwyrm/cli.rb`.
- Identify which command/subcommand and options are affected.

2. Keep behavior deterministic:
- Separate prompting (`TTY::Prompt`) from execution logic.
- Keep filesystem/command side effects in service classes (`Generator`, `Shell`).

3. Preserve UX style:
- Keep colorful, icon-rich output via `UI::Console`.
- Show concise success/failure states for each step.
- Keep banner optional via `--no-banner`.

4. Update tests with behavior changes:
- Add or update specs under `spec/railwyrm`.
- Prefer verifying command plans and side effects over brittle output snapshots.

5. Re-run quality gates:
- Run `bundle exec rspec`.
- If flags/flows changed, update `README.md` command examples.

## File map

- `lib/railwyrm/cli.rb`: command entrypoints and option handling.
- `lib/railwyrm/ui.rb`: banner, colors, icons, and step rendering.
- `lib/railwyrm/shell.rb`: external command runner.
- `spec/railwyrm/*`: behavior tests.

## Guardrails

- Validate user input at configuration boundaries.
- Prefer explicit error messages over silent fallback.
- Keep `--interactive=false` fully functional for scripts/CI.
