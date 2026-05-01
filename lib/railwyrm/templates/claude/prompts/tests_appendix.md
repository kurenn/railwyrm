## Railwyrm Test Conventions

### Factory Preferences

- **Prefer `build_stubbed`** over `create` in unit tests. Only use `create` when the test requires database persistence (e.g., testing scopes, uniqueness validations, or query behavior).
- Keep factories minimal. Override attributes in individual tests, not in the factory definition.

### Component Specs

Write specs for every ViewComponent in `spec/components/`:

```ruby
RSpec.describe Ui::Button::Component, type: :component do
  it "renders a primary button" do
    render_inline(described_class.new(variant: :primary)) { "Save" }

    expect(page).to have_button("Save")
  end
end
```

### Request Specs

Write request specs in `spec/requests/`, not controller specs:

```ruby
RSpec.describe "Items", type: :request do
  describe "POST /items" do
    it "creates an item and redirects" do
      post items_path, params: { item: { name: "Widget" } }

      expect(response).to redirect_to(Item.last)
      expect(Item.count).to eq(1)
    end
  end
end
```

### Model Spec Structure

Group model specs by category:

```ruby
RSpec.describe User, type: :model do
  describe "validations" do
    it { is_expected.to validate_presence_of(:email) }
  end

  describe "associations" do
    it { is_expected.to have_many(:posts).dependent(:destroy) }
  end

  describe "scopes" do
    describe ".active" do
      it "excludes archived users" do
        active = create(:user, archived_at: nil)
        create(:user, archived_at: Time.current)
        expect(User.active).to eq([active])
      end
    end
  end
end
```
