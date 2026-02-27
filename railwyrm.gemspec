# frozen_string_literal: true

require_relative "lib/railwyrm/version"

Gem::Specification.new do |spec|
  spec.name = "railwyrm"
  spec.version = Railwyrm::VERSION
  spec.authors = ["Codex + Abraham"]
  spec.email = ["abraham@example.com"]

  spec.summary = "Epic interactive Rails project kickstarter"
  spec.description = "Railwyrm is a Claude-CLI-inspired generator for bootstrapping production-ready Rails apps and serving creation requests over HTTP."
  spec.homepage = "https://example.com/railwyrm"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata = {
    "homepage_uri" => spec.homepage,
    "source_code_uri" => spec.homepage,
    "changelog_uri" => spec.homepage
  }

  spec.files = Dir.glob(
    "{AGENTS.md,README.md,Rakefile,config.ru,.rspec,.gitignore,exe/*,lib/**/*.rb,lib/**/*.erb,spec/**/*.rb,.codex/skills/**/SKILL.md}"
  )
  spec.bindir = "exe"
  spec.executables = ["railwyrm"]
  spec.require_paths = ["lib"]

  spec.add_dependency "pastel", "~> 0.8"
  spec.add_dependency "puma", "~> 6.6"
  spec.add_dependency "rackup", "~> 2.2"
  spec.add_dependency "sinatra", "~> 4.1"
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "tty-font", "~> 0.5"
  spec.add_dependency "tty-prompt", "~> 0.23"
  spec.add_dependency "tty-spinner", "~> 0.9"

  spec.add_development_dependency "rake", "~> 13.2"
  spec.add_development_dependency "rspec", "~> 3.13"
end
