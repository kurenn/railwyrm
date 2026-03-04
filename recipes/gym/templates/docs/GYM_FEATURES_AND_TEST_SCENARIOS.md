# Gym Features and Test Scenarios

## Core Features

- Member management (create, edit, search, profile)
- Visit tracking (staff check-ins)
- Membership plan management
- Class session management
- Class booking lifecycle (book, attend, cancel)
- Public class schedule page
- Public membership request form
- Dashboard and operational reports

## Seeded Access

- `admin@gym.local`
- `manager@gym.local`
- `staff@gym.local`
- `trainer@gym.local`
- Password for all seeded users: `Password123!`

## Manual Test Scenarios

1. Sign in as `manager@gym.local` and verify dashboard metrics load.
2. Create a new member from `Members > New member`.
3. Open `Visits` and record a check-in for that member.
4. Create a membership plan from `Membership plans > New plan`.
5. Create a class session from `Class sessions > New class`.
6. Open that class session and book a member.
7. Mark the booking as attended.
8. Open `Reports` and verify counts render.
9. Visit `/schedule` logged out and verify upcoming classes are visible.
10. Visit `/memberships/new` logged out and submit a membership request.

## Test Commands

```bash
bin/rails db:migrate
bin/rails db:seed
bundle exec rspec
bin/rails routes
bin/rails zeitwerk:check
```
