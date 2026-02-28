# ATS Recipe Prompt (Test)

Use this prompt in Codex/Claude against a newly generated Railwyrm app to test
the ATS recipe behavior before wiring a native `--recipe` implementation.

## Copy/Paste Prompt

```text
You are implementing an ATS (Applicant Tracking System) overlay in an existing Rails app that was created by Railwyrm.

Context:
- Rails app already includes Tailwind, PostgreSQL, RSpec, Devise, Active Storage, ActionText, untitled_ui, and claude-on-rails.
- Use the ATS recipe spec at: recipes/ats/recipe.yml (in the railwyrm repo) as source of truth.
- Goal is a clean, responsive MVP with deterministic scaffolding and minimal surprise.

Hard requirements:
1) Implement the core ATS data model and enums from the recipe.
2) Add Pundit authorization with baseline policies for jobs/candidates/applications/interviews/reports.
3) Add responsive UI pages for:
   - ATS dashboard
   - jobs index/show
   - candidates index/show
   - application pipeline board
   - reports overview
4) Use Untitled UI view components for ATS pages.
5) Keep pages fully responsive (mobile-first Tailwind classes).
6) Add seed data for realistic local demo.
7) Keep implementation explicit and maintainable; avoid giant monolithic files.
8) If background jobs are needed, use Solid Queue (`solid_queue`) instead of Sidekiq.

Delivery constraints:
- No inline CSS.
- No social login UI.
- Keep naming consistent with Rails conventions.
- If a generator choice is ambiguous, choose the simplest approach and document it.

Execution steps:
1) Read and summarize `recipes/ats/recipe.yml`.
2) Implement models/migrations/enums/associations.
3) Implement controllers/routes/policies.
4) Implement responsive views and any needed ViewComponents/partials.
5) Implement seeds.
6) Run and report:
   - bundle exec rspec
   - bin/rails routes
   - bin/rails zeitwerk:check
7) Return a concise changelog with file paths and key decisions.

Output format:
- Section 1: What was implemented
- Section 2: Commands executed and results
- Section 3: Remaining TODOs (if any)
```

## Suggested local test flow

```bash
# 1) generate a base app
railwyrm new ats_test --path /tmp --interactive=false --sign_in_layout card_combined

# 2) open the app in your coding assistant session
cd /tmp/ats_test

# 3) paste the prompt above into Codex/Claude and execute
```
