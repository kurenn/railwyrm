# frozen_string_literal: true

module Railwyrm
  class RailsBlueprint
    RAILS_NEW_FLAGS = [
      "--database=postgresql",
      "--css=tailwind",
      "--skip-test",
      "--skip-bundle"
    ].freeze

    def rails_new_command(configuration)
      ["rails", "new", configuration.name, *RAILS_NEW_FLAGS]
    end

    def gem_entries
      [
        {
          marker: 'gem "devise"',
          snippet: 'gem "devise"'
        },
        {
          marker: 'gem "untitled_ui"',
          snippet: 'gem "untitled_ui", github: "coba-ai/untitled.ui", branch: "main"'
        },
        {
          marker: 'gem "rspec-rails"',
          snippet: <<~RUBY.strip
            group :development, :test do
              gem "rspec-rails"
            end
          RUBY
        },
        {
          marker: 'gem "claude-on-rails"',
          snippet: <<~RUBY.strip
            group :development do
              gem "claude-on-rails"
            end
          RUBY
        }
      ]
    end

    def post_bundle_steps(configuration)
      steps = [
        ["Install Tailwind CSS", ["./bin/rails", "tailwindcss:install"]],
        ["Install Active Storage", ["bin/rails", "active_storage:install"]],
        ["Install ActionText", ["bin/rails", "action_text:install"]],
        ["Install Untitled UI", ["bin/rails", "generate", "untitled_ui:install"]],
        ["Install RSpec", ["bin/rails", "generate", "rspec:install"]],
        ["Install Devise", ["bin/rails", "generate", "devise:install"]]
      ]

      if configuration.install_devise_user?
        steps << [
          "Generate #{configuration.devise_user_model} model with Devise",
          ["bin/rails", "generate", "devise", configuration.devise_user_model]
        ]
      end

      steps.concat(
        [
          ["Install Claude on Rails swarm", ["bin/rails", "generate", "claude_on_rails:swarm"]],
          ["Create database", ["bin/rails", "db:create"]],
          ["Run database migrations", ["bin/rails", "db:migrate"]]
        ]
      )
    end
  end
end
