## Railwyrm Controller Conventions

### Thin Controllers

- Max 10 lines of meaningful logic per action. If an action is longer, extract a service object.
- Controllers receive requests, delegate to models/services, and render responses. That is all.

### Turbo Stream Responses

Always respond to `turbo_stream` format alongside HTML:

```ruby
def create
  @item = Item.new(item_params)

  if @item.save
    respond_to do |format|
      format.html { redirect_to @item, notice: "Item created." }
      format.turbo_stream
    end
  else
    render :new, status: :unprocessable_entity
  end
end
```

Create matching `app/views/items/create.turbo_stream.erb` templates for Turbo Stream responses.

### Service Object Delegation

For multi-step operations, delegate to service objects:

```ruby
def create
  result = CreateOrder.call(order_params: order_params, user: current_user)

  if result.success?
    redirect_to result.order, notice: "Order placed."
  else
    @order = result.order
    render :new, status: :unprocessable_entity
  end
end
```

### Authentication and Authorization

- Use `before_action :authenticate_user!` for Devise authentication.
- Scope queries to `current_user` to prevent unauthorized access.
- Use Pundit or similar for authorization when role-based access is needed.
