# Fly Deploy Checklist (ATS)

1. Set secrets in Fly:
   - `fly secrets set RAILS_MASTER_KEY=...`
2. Confirm Postgres attachment and `DATABASE_URL` availability.
3. Deploy with release command/migrations enabled.
4. Run smoke check after deploy:
   - `bin/rails runner "puts 'railwyrm_fly_smoke_ok'"`
5. Verify health endpoint manually:
   - `GET /careers` returns HTTP 200.
6. Run one ATS routing sanity check:
   - authenticated `/reports` resolves without 500.
