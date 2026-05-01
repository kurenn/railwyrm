## Untitled UI Component Rules

This project uses the **untitled_ui** gem as its ONLY UI component library. All components follow the `Ui::<Name>::Component` naming convention.

### Mandatory Rules

1. **ALWAYS use `Ui::` components** for standard UI elements. Never write raw HTML `<button>`, `<input>`, `<select>`, `<textarea>`, `<table>`, or modal markup.
2. **Render syntax**: `render(Ui::Button::Component.new(variant: :primary))` with block or `with_content`.
3. **Form inputs**: Use `Ui::Input::Component`, `Ui::Select::Component`, `Ui::Checkbox::Component`, `Ui::RadioButton::Component`, `Ui::Textarea::Component`, `Ui::DatePicker::Component`, `Ui::FileUpload::Component`.
4. **Feedback elements**: Use `Ui::Alert::Component`, `Ui::Toast::Component`, `Ui::Badge::Component`, `Ui::HintText::Component`.
5. **Layout elements**: Use `Ui::Card::Component`, `Ui::Modal::Component`, `Ui::Drawer::Component`, `Ui::Accordion::Component`, `Ui::Tabs::Component`.
6. **Navigation**: Use `Ui::Navigation::Component`, `Ui::Breadcrumb::Component`, `Ui::Pagination::Component`.
7. **Data display**: Use `Ui::Table::Component`, `Ui::Stat::Component`, `Ui::Timeline::Component`, `Ui::ProgressBar::Component`, `Ui::Skeleton::Component`.

### Component Slots

Many components use ViewComponent slots (`renders_one`, `renders_many`). Use the `with_*` API:

```erb
<%%= render(Ui::Card::Component.new) do |c| %>
  <%% c.with_header { "Title" } %>
  <p>Card body</p>
  <%% c.with_footer { "Footer" } %>
<%% end %>
```

### Common Patterns

```erb
<%% # Button %>
<%%= render(Ui::Button::Component.new(variant: :primary, size: :md)) { "Save" } %>

<%% # Input with label %>
<%%= render(Ui::Label::Component.new(for: "email")) { "Email" } %>
<%%= render(Ui::Input::Component.new(name: "email", type: :email, placeholder: "you@example.com")) %>

<%% # Alert %>
<%%= render(Ui::Alert::Component.new(variant: :success)) { "Changes saved." } %>

<%% # Modal %>
<%%= render(Ui::Modal::Component.new(title: "Confirm")) do |m| %>
  <p>Are you sure?</p>
<%% end %>

<%% # Table %>
<%%= render(Ui::Table::Component.new) do |t| %>
  <%% t.with_header do %>
    <tr><th>Name</th><th>Status</th></tr>
  <%% end %>
  <%% @items.each do |item| %>
    <tr><td><%%= item.name %></td><td><%%= item.status %></td></tr>
  <%% end %>
<%% end %>
```
