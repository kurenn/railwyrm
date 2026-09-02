# frozen_string_literal: true

module Railwyrm
  class RailsBlueprint
    # Generation uses this exact version so the Gemfile it writes is already
    # correct, rather than being patched afterwards.
    DEFAULT_RAILS_VERSION = "8.1.3.1"
    RAILS_NEW_FLAGS = [
      "--database=postgresql",
      "--css=tailwind",
      "--skip-test",
      "--skip-bundle"
    ].freeze

    def rails_new_command(configuration, rails_version: nil)
      selector = rails_version.to_s.strip.empty? ? [] : ["_#{rails_version}_"]
      ["rails", *selector, "new", configuration.name, *RAILS_NEW_FLAGS]
    end

    def default_rails_version
      DEFAULT_RAILS_VERSION
    end

    def gem_entries
      [
        {
          marker: 'gem "devise"',
          snippet: 'gem "devise"'
        },
        {
          marker: 'gem "rspec-rails"',
          snippet: <<~RUBY.strip
            group :development, :test do
              gem "rspec-rails"
              gem "dotenv-rails"
            end
          RUBY
        },
        {
          marker: 'gem "ruby-lsp"',
          snippet: <<~RUBY.strip
            group :development do
              gem "ruby-lsp", require: false
            end
          RUBY
        },
        {
          marker: 'gem "brakeman"',
          snippet: 'gem "brakeman", require: false'
        },
        {
          marker: 'gem "rubocop-rails"',
          snippet: <<~RUBY.strip
            group :development, :test do
              gem "rubocop", require: false
              gem "rubocop-rails", require: false
            end
          RUBY
        },
        {
          marker: 'gem "bullet"',
          snippet: <<~RUBY.strip
            group :development do
              gem "bullet"
            end
          RUBY
        }
      ]
    end

    def optional_gem_entries(configuration)
      entries = []

      if configuration.devise_magic_link?
        entries << {
          marker: 'gem "devise-passwordless"',
          snippet: 'gem "devise-passwordless"'
        }
      end

      if configuration.devise_passkeys?
        entries << {
          marker: 'gem "devise-webauthn"',
          snippet: 'gem "devise-webauthn"'
        }
      end

      entries
    end

    def post_bundle_steps(configuration)
      steps = [
        ["Install Tailwind CSS", ["./bin/rails", "tailwindcss:install"]],
        ["Install Active Storage", ["bin/rails", "active_storage:install"]],
        ["Install ActionText", ["bin/rails", "action_text:install"]],
        # The two installers above can uncomment gems (image_processing), which
        # leaves the bundle stale and breaks every bin/rails call after them.
        ["Install gems added by the installers", ["bundle", "install"]],
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
          ["Create database", ["bin/rails", "db:create"]],
          ["Run database migrations", ["bin/rails", "db:migrate"]]
        ]
      )
    end
  end
end
