# Render Deploy Checklist (ATS)

1. Set `RAILS_MASTER_KEY` in Render environment variables.
2. Set `DATABASE_URL` and verify Postgres connectivity.
3. Ensure `RAILS_ENV=production` and `RAILS_LOG_TO_STDOUT=true`.
4. Run smoke check after deploy:
   - `bin/rails runner "puts 'railwyrm_render_smoke_ok'"`
5. Verify health endpoint manually:
   - `GET /careers` returns HTTP 200.
6. Run one auth flow check:
   - Sign in with seeded recruiter account.
