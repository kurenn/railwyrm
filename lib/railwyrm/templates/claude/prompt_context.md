# PROMPT_CONTEXT.md

Use this file to translate annotated HTML prototypes into Rails views with untitled_ui ViewComponents.

## Prototype Annotation Reference

Prototypes use HTML comments to annotate which ViewComponent to use. Map each annotation to its render call:

| Annotation | ViewComponent | Render Call |
|-----------|--------------|------------|
| `vc:accordion` | Ui::Accordion::Component | `render(Ui::Accordion::Component.new(...))` |
| `vc:alert` | Ui::Alert::Component | `render(Ui::Alert::Component.new(...))` |
| `vc:avatar` | Ui::Avatar::Component | `render(Ui::Avatar::Component.new(...))` |
| `vc:badge` | Ui::Badge::Component | `render(Ui::Badge::Component.new(...))` |
| `vc:breadcrumb` | Ui::Breadcrumb::Component | `render(Ui::Breadcrumb::Component.new(...))` |
| `vc:button` | Ui::Button::Component | `render(Ui::Button::Component.new(...))` |
| `vc:button_group` | Ui::ButtonGroup::Component | `render(Ui::ButtonGroup::Component.new(...))` |
| `vc:card` | Ui::Card::Component | `render(Ui::Card::Component.new(...))` |
| `vc:checkbox` | Ui::Checkbox::Component | `render(Ui::Checkbox::Component.new(...))` |
| `vc:close_button` | Ui::CloseButton::Component | `render(Ui::CloseButton::Component.new(...))` |
| `vc:color_picker` | Ui::ColorPicker::Component | `render(Ui::ColorPicker::Component.new(...))` |
| `vc:command_palette` | Ui::CommandPalette::Component | `render(Ui::CommandPalette::Component.new(...))` |
| `vc:date_picker` | Ui::DatePicker::Component | `render(Ui::DatePicker::Component.new(...))` |
| `vc:dot_icon` | Ui::DotIcon::Component | `render(Ui::DotIcon::Component.new(...))` |
| `vc:drawer` | Ui::Drawer::Component | `render(Ui::Drawer::Component.new(...))` |
| `vc:dropdown` | Ui::Dropdown::Component | `render(Ui::Dropdown::Component.new(...))` |
| `vc:empty_state` | Ui::EmptyState::Component | `render(Ui::EmptyState::Component.new(...))` |
| `vc:featured_icon` | Ui::FeaturedIcon::Component | `render(Ui::FeaturedIcon::Component.new(...))` |
| `vc:file_upload` | Ui::FileUpload::Component | `render(Ui::FileUpload::Component.new(...))` |
| `vc:hint_text` | Ui::HintText::Component | `render(Ui::HintText::Component.new(...))` |
| `vc:input` | Ui::Input::Component | `render(Ui::Input::Component.new(...))` |
| `vc:label` | Ui::Label::Component | `render(Ui::Label::Component.new(...))` |
| `vc:loading_indicator` | Ui::LoadingIndicator::Component | `render(Ui::LoadingIndicator::Component.new(...))` |
| `vc:modal` | Ui::Modal::Component | `render(Ui::Modal::Component.new(...))` |
| `vc:navigation` | Ui::Navigation::Component | `render(Ui::Navigation::Component.new(...))` |
| `vc:pagination` | Ui::Pagination::Component | `render(Ui::Pagination::Component.new(...))` |
| `vc:progress_bar` | Ui::ProgressBar::Component | `render(Ui::ProgressBar::Component.new(...))` |
| `vc:progress_steps` | Ui::ProgressSteps::Component | `render(Ui::ProgressSteps::Component.new(...))` |
| `vc:radio_button` | Ui::RadioButton::Component | `render(Ui::RadioButton::Component.new(...))` |
| `vc:select` | Ui::Select::Component | `render(Ui::Select::Component.new(...))` |
| `vc:skeleton` | Ui::Skeleton::Component | `render(Ui::Skeleton::Component.new(...))` |
| `vc:slider` | Ui::Slider::Component | `render(Ui::Slider::Component.new(...))` |
| `vc:stat` | Ui::Stat::Component | `render(Ui::Stat::Component.new(...))` |
| `vc:stepper` | Ui::Stepper::Component | `render(Ui::Stepper::Component.new(...))` |
| `vc:table` | Ui::Table::Component | `render(Ui::Table::Component.new(...))` |
| `vc:tabs` | Ui::Tabs::Component | `render(Ui::Tabs::Component.new(...))` |
| `vc:tag_input` | Ui::TagInput::Component | `render(Ui::TagInput::Component.new(...))` |
| `vc:textarea` | Ui::Textarea::Component | `render(Ui::Textarea::Component.new(...))` |
| `vc:timeline` | Ui::Timeline::Component | `render(Ui::Timeline::Component.new(...))` |
| `vc:toast` | Ui::Toast::Component | `render(Ui::Toast::Component.new(...))` |
| `vc:toggle` | Ui::Toggle::Component | `render(Ui::Toggle::Component.new(...))` |
| `vc:tooltip` | Ui::Tooltip::Component | `render(Ui::Tooltip::Component.new(...))` |

## Property Annotations

`prop:` annotations map to component initializer parameters:

```html
<!-- prop:variant="primary" prop:size="lg" prop:disabled="true" -->
```

Translates to:

```erb
<%= render(Ui::Button::Component.new(variant: :primary, size: :lg, disabled: true)) { "Submit" } %>
```

Rules:
- String values that match a known set of options become symbols (`:primary`, `:lg`, `:sm`)
- Boolean strings (`"true"`, `"false"`) become Ruby booleans
- Numeric strings become integers or floats as appropriate
- All other values remain strings

## Slot Annotations

`slot:` annotations map to ViewComponent slots:

```html
<!-- slot:header -->
<h2>Card Title</h2>
<!-- /slot:header -->

<!-- slot:footer -->
<p>Footer text</p>
<!-- /slot:footer -->
```

Translates to:

```erb
<%= render(Ui::Card::Component.new) do |c| %>
  <% c.with_header do %>
    <h2>Card Title</h2>
  <% end %>

  <% c.with_footer do %>
    <p>Footer text</p>
  <% end %>
<% end %>
```

## Stimulus Annotations

`stimulus:` annotations map to Stimulus controllers:

```html
<!-- stimulus:dropdown -->
<div data-controller="dropdown">
  ...
</div>
```

Rules:
- `stimulus:name` becomes `data-controller="name"`
- `stimulus:name.target="menu"` becomes `data-name-target="menu"`
- `stimulus:name.action="click->toggle"` becomes `data-action="click->name#toggle"`

## Stack Summary

| Layer | Technology |
|-------|-----------|
| Framework | Rails 8 |
| Database | PostgreSQL |
| CSS | Tailwind CSS (via tailwindcss-rails) |
| UI Components | untitled_ui gem (ViewComponent) |
| Frontend | Hotwire (Turbo + Stimulus) |
| Auth | Devise |
| Testing | RSpec + FactoryBot |
| Linting | RuboCop + rubocop-rails |
| Security | Brakeman |
| N+1 Detection | Bullet |
| AI Development | claude-on-rails (agent swarm) |

## Tailwind Tokens Reference

### Colors
Use Tailwind's default palette plus any custom tokens defined in `config/tailwind.config.js`.

### Spacing
Standard Tailwind spacing scale: `0`, `0.5`, `1`, `1.5`, `2`, `2.5`, `3`, `3.5`, `4`, `5`, `6`, `7`, `8`, `9`, `10`, `11`, `12`, `14`, `16`, `20`, `24`, `28`, `32`, `36`, `40`, `44`, `48`, `52`, `56`, `60`, `64`, `72`, `80`, `96`.

### Typography
- Sizes: `text-xs`, `text-sm`, `text-base`, `text-lg`, `text-xl`, `text-2xl` through `text-9xl`
- Weights: `font-thin`, `font-extralight`, `font-light`, `font-normal`, `font-medium`, `font-semibold`, `font-bold`, `font-extrabold`, `font-black`
- Leading: `leading-none`, `leading-tight`, `leading-snug`, `leading-normal`, `leading-relaxed`, `leading-loose`
