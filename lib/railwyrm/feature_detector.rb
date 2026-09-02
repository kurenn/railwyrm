# frozen_string_literal: true

module Railwyrm
  class FeatureDetector
    COLUMN_BACKED_MODULES = {
      "confirmable" => "confirmation_token",
      "lockable" => "unlock_token",
      "trackable" => "sign_in_count"
    }.freeze

    def initialize(app_path:, devise_user_model: "User")
      @app_path = File.expand_path(app_path)
      @devise_user_model = devise_user_model.to_s.strip.empty? ? "User" : devise_user_model.to_s.strip
    end

    def detect
      model_content = read_optional_file("app/models/#{underscore(devise_user_model)}.rb")
      routes_content = read_optional_file("config/routes.rb")
      gemfile_content = read_optional_file("Gemfile")
      ci_workflow = read_optional_file(".github/workflows/ci.yml")
      development_content = read_optional_file("config/environments/development.rb")
      devise_modules = extract_devise_modules(model_content)

      detected = []
      detected << "confirmable" if devise_module_installed?("confirmable", devise_modules)
      detected << "lockable" if devise_module_installed?("lockable", devise_modules)
      detected << "timeoutable" if devise_modules.include?("timeoutable")
      detected << "trackable" if devise_module_installed?("trackable", devise_modules)

      if devise_modules.include?("magic_link_authenticatable") ||
         routes_content.include?('controllers: { sessions: "devise/passwordless/sessions" }') ||
         gemfile_content.include?('gem "devise-passwordless"')
        detected << "magic_link"
      end

      if devise_modules.include?("passkey_authenticatable") ||
         gemfile_content.include?('gem "devise-webauthn"')
        detected << "passkeys"
      end

      detected << "ci" unless ci_workflow.strip.empty?

      if quality_tooling_detected?(gemfile_content, development_content) && detected.include?("ci")
        detected << "quality"
      end

      ordered_features(detected)
    end

    private

    attr_reader :app_path, :devise_user_model

    # A column-backed module counts as installed only once its columns exist;
    # the declaration on its own can outlive a failed migration.
    def devise_module_installed?(name, devise_modules)
      return false unless devise_modules.include?(name)

      column = COLUMN_BACKED_MODULES.fetch(name)
      schema_defines_column?(column) || migrations_define_column?(column)
    end

    def schema_defines_column?(column)
      read_optional_file("db/schema.rb").include?(column) ||
        read_optional_file("db/structure.sql").include?(column)
    end

    def migrations_define_column?(column)
      Dir.glob(File.join(app_path, "db/migrate/*.rb")).any? { |path| File.read(path).include?(column) }
    end

    def read_optional_file(relative_path)
      path = File.join(app_path, relative_path)
      return "" unless File.exist?(path)

      File.read(path)
    end

    def ordered_features(values)
      values.each_with_object([]) do |value, ordered|
        ordered << value unless ordered.include?(value)
      end
    end

    def quality_tooling_detected?(gemfile_content, development_content)
      gemfile_content.include?('gem "brakeman"') &&
        gemfile_content.include?('gem "rubocop"') &&
        gemfile_content.include?('gem "rubocop-rails"') &&
        gemfile_content.include?('gem "bullet"') &&
        development_content.include?("Bullet.enable = true")
    end

    def extract_devise_modules(model_content)
      lines = model_content.lines
      declaration_start = lines.index { |line| line.match?(/^\s*devise\s+/) }
      return [] if declaration_start.nil?

      declaration_end = declaration_start
      while declaration_end + 1 < lines.length && lines[declaration_end].rstrip.end_with?(",")
        declaration_end += 1
      end

      lines[declaration_start..declaration_end].join.scan(/:([a-z_]+)/).flatten
    end

    def underscore(value)
      value.to_s
           .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
           .gsub(/([a-z\d])([A-Z])/, '\1_\2')
           .tr("-", "_")
           .downcase
    end
  end
end
