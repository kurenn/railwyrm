# frozen_string_literal: true

module Railwyrm
  class FeatureRegistry
    FEATURES = {
      "confirmable" => {
        description: "Require email confirmation before sign in",
        dependencies: []
      },
      "lockable" => {
        description: "Lock accounts after repeated failed sign-in attempts",
        dependencies: []
      },
      "timeoutable" => {
        description: "Automatically sign out inactive users",
        dependencies: []
      },
      "trackable" => {
        description: "Track sign-in count, timestamps, and IP addresses",
        dependencies: []
      },
      "magic_link" => {
        description: "Enable passwordless email magic-link sign in",
        dependencies: ["trackable"]
      },
      "passkeys" => {
        description: "Enable passkeys sign-in with WebAuthn (devise-webauthn)",
        dependencies: []
      },
      "ci" => {
        description: "Add a GitHub Actions CI workflow (RSpec, RuboCop, Brakeman)",
        dependencies: []
      }
    }.freeze

    def self.list
      FEATURES.keys.sort
    end

    def self.fetch(feature_name)
      FEATURES[feature_name.to_s]
    end

    def self.resolve(features)
      requested = Array(features).map(&:to_s).map(&:strip).reject(&:empty?)
      raise InvalidConfiguration, "At least one feature must be provided." if requested.empty?

      unknown = requested.reject { |feature| FEATURES.key?(feature) }
      unless unknown.empty?
        raise InvalidConfiguration,
              "Unknown feature(s): #{unknown.join(', ')}. Supported: #{list.join(', ')}"
      end

      resolved = []
      requested.each do |feature|
        append_with_dependencies(feature, resolved)
      end
      resolved
    end

    def self.append_with_dependencies(feature, resolved)
      dependencies = FEATURES.fetch(feature).fetch(:dependencies)
      dependencies.each { |dependency| append_with_dependencies(dependency, resolved) }
      resolved << feature unless resolved.include?(feature)
    end

    private_class_method :append_with_dependencies
  end
end
