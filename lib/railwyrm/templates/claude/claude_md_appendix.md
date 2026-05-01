## Untitled UI Component Map

This project uses the **untitled_ui** gem for all UI components. Every component follows the `Ui::<Name>::Component` naming convention and lives in `app/components/ui/`.

**Never write raw HTML** for any element that has a corresponding Ui component. Always use the ViewComponent render call.

### Available Components

| Component | Render Call |
|-----------|------------|
| Accordion | `render(Ui::Accordion::Component.new(...))` |
| Alert | `render(Ui::Alert::Component.new(...))` |
| Avatar | `render(Ui::Avatar::Component.new(...))` |
| Badge | `render(Ui::Badge::Component.new(...))` |
| Breadcrumb | `render(Ui::Breadcrumb::Component.new(...))` |
| Button | `render(Ui::Button::Component.new(...))` |
| ButtonGroup | `render(Ui::ButtonGroup::Component.new(...))` |
| Card | `render(Ui::Card::Component.new(...))` |
| Checkbox | `render(Ui::Checkbox::Component.new(...))` |
| CloseButton | `render(Ui::CloseButton::Component.new(...))` |
| ColorPicker | `render(Ui::ColorPicker::Component.new(...))` |
| CommandPalette | `render(Ui::CommandPalette::Component.new(...))` |
| DatePicker | `render(Ui::DatePicker::Component.new(...))` |
| DotIcon | `render(Ui::DotIcon::Component.new(...))` |
| Drawer | `render(Ui::Drawer::Component.new(...))` |
| Dropdown | `render(Ui::Dropdown::Component.new(...))` |
| EmptyState | `render(Ui::EmptyState::Component.new(...))` |
| FeaturedIcon | `render(Ui::FeaturedIcon::Component.new(...))` |
| FileUpload | `render(Ui::FileUpload::Component.new(...))` |
| HintText | `render(Ui::HintText::Component.new(...))` |
| Input | `render(Ui::Input::Component.new(...))` |
| Label | `render(Ui::Label::Component.new(...))` |
| LoadingIndicator | `render(Ui::LoadingIndicator::Component.new(...))` |
| Modal | `render(Ui::Modal::Component.new(...))` |
| Navigation | `render(Ui::Navigation::Component.new(...))` |
| Pagination | `render(Ui::Pagination::Component.new(...))` |
| ProgressBar | `render(Ui::ProgressBar::Component.new(...))` |
| ProgressSteps | `render(Ui::ProgressSteps::Component.new(...))` |
| RadioButton | `render(Ui::RadioButton::Component.new(...))` |
| Select | `render(Ui::Select::Component.new(...))` |
| Skeleton | `render(Ui::Skeleton::Component.new(...))` |
| Slider | `render(Ui::Slider::Component.new(...))` |
| Stat | `render(Ui::Stat::Component.new(...))` |
| Stepper | `render(Ui::Stepper::Component.new(...))` |
| Table | `render(Ui::Table::Component.new(...))` |
| Tabs | `render(Ui::Tabs::Component.new(...))` |
| TagInput | `render(Ui::TagInput::Component.new(...))` |
| Textarea | `render(Ui::Textarea::Component.new(...))` |
| Timeline | `render(Ui::Timeline::Component.new(...))` |
| Toast | `render(Ui::Toast::Component.new(...))` |
| Toggle | `render(Ui::Toggle::Component.new(...))` |
| Tooltip | `render(Ui::Tooltip::Component.new(...))` |

## Architecture Rules

- **Thin controllers**: Max 10 lines of meaningful logic per action. Controllers receive requests, delegate to models or service objects, and render responses.
- **Service objects**: Place in `app/services/`. One public method (`call`). Use for multi-step business logic, cross-model operations, or anything that doesn't fit cleanly in a single model.
- **Fat models with concerns**: Business logic belongs in models. Extract shared behavior into concerns under `app/models/concerns/` when two or more models share it, or a model exceeds ~150 lines.
- **No `update_column`/`update_columns`**: Always use `update`/`update!` to ensure callbacks and validations run.
- **Enums with validation**: Always use `enum :status, { ... }, validate: true` to reject invalid values gracefully.
- **Scopes for queries**: Define named scopes for all common query patterns. Never scatter raw `where` calls across controllers.

## Test Conventions

- **RSpec + FactoryBot**: All tests use RSpec. Factories live in `spec/factories/`.
- **Prefer `build_stubbed`**: Use `build_stubbed` over `create` in unit tests unless database persistence is required for the assertion.
- **Request specs for controllers**: Write `spec/requests/` specs, not controller specs. Assert response status, body content, and redirects.
- **Component specs for ViewComponent**: Test every `Ui::` component usage in `spec/components/`. Use `render_inline` and assert with Capybara matchers.
- **Model specs**: Test validations, associations, scopes, and business methods. Group by category (`describe "validations"`, `describe "scopes"`).
- **No mocks for database**: Integration tests hit the real database. Mocks can mask migration and query issues.
