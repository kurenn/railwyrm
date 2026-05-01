## Railwyrm Model Conventions

### Enum Rules

Always use the keyword syntax with `validate: true`:

```ruby
enum :status, { draft: 0, published: 1, archived: 2 }, validate: true
enum :role, { admin: 0, editor: 1, viewer: 2 }, validate: true, prefix: true
```

Never use string-backed enums unless there is a documented reason. Integer-backed enums are the default.

### Update Rules

- **Never use `update_column` or `update_columns`**. These skip validations and callbacks, leading to data integrity issues.
- Always use `update` or `update!`. If you need to skip callbacks intentionally, document why with a code comment.

### Scope Rules

- Define named scopes for every common query pattern. Controllers and views should call scopes, not chain raw `where` clauses.
- Prefer `scope :active, -> { where(archived_at: nil) }` over class methods for simple conditions.
- Compose scopes: `User.active.recent.verified` reads better than a single complex query.

### Concern Extraction

- Extract into `app/models/concerns/` when two or more models share behavior.
- Extract when a model exceeds ~150 lines with a clearly separable responsibility.
- Do NOT extract single-method, single-use behavior into a concern.
