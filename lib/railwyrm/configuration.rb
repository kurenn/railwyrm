# frozen_string_literal: true

module Railwyrm
  class Configuration
    NAME_PATTERN = /\A[a-z][a-z0-9_]*\z/
    SIGN_IN_LAYOUTS = %w[simple_minimal card_combined split_mockup_quote].freeze

    attr_reader :name, :workspace, :devise_user_model, :sign_in_layout, :dry_run, :verbose

    def initialize(
      name:,
      workspace:,
      devise_user_model: "User",
      sign_in_layout: "card_combined",
      install_devise_user: true,
      dry_run: false,
      verbose: false
    )
      @name = name.to_s.strip
      @workspace = File.expand_path(workspace.to_s.strip.empty? ? Dir.pwd : workspace)
      @devise_user_model = devise_user_model.to_s.strip.empty? ? "User" : devise_user_model.to_s.strip
      @sign_in_layout = sign_in_layout.to_s.strip.empty? ? "card_combined" : sign_in_layout.to_s.strip
      @install_devise_user = install_devise_user
      @dry_run = dry_run
      @verbose = verbose

      validate!
    end

    def install_devise_user?
      @install_devise_user
    end

    def app_path
      File.join(workspace, name)
    end

    def to_h
      {
        name: name,
        workspace: workspace,
        devise_user_model: devise_user_model,
        sign_in_layout: sign_in_layout,
        install_devise_user: install_devise_user?,
        dry_run: dry_run,
        verbose: verbose
      }
    end

    private

    def validate!
      raise InvalidConfiguration, "App name is required." if name.empty?
      raise InvalidConfiguration, "App name must be snake_case and start with a letter." unless name.match?(NAME_PATTERN)
      raise InvalidConfiguration, "Workspace path is required." if workspace.empty?
      return if SIGN_IN_LAYOUTS.include?(sign_in_layout)

      raise InvalidConfiguration,
            "Sign-in layout must be one of: #{SIGN_IN_LAYOUTS.join(', ')}"
    end
  end
end
