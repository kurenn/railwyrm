# frozen_string_literal: true

require_relative "lib/railwyrm/version"

Gem::Specification.new do |spec|
  spec.name = "railwyrm"
  spec.version = Railwyrm::VERSION
  spec.authors = ["Abraham Kuri"]
  spec.email = ["abkuri88@gmail.com"]

  spec.summary = "Epic interactive Rails project kickstarter"
  spec.description = "Railwyrm is a Claude-CLI-inspired generator for bootstrapping production-ready Rails apps and serving creation requests over HTTP."
  spec.homepage = "https://github.com/kurenn/railwyrm"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.2.0"

  spec.metadata = {
    "source_code_uri" => spec.homepage,
    "bug_tracker_uri" => "#{spec.homepage}/issues"
  }

  spec.files = Dir.glob(
    "{AGENTS.md,README.md,VISION.md,Rakefile,config.ru,.rspec,.gitignore,exe/*,lib/**/*.rb,lib/railwyrm/templates/**/*,spec/**/*.rb,recipes/**/*,.codex/skills/**/SKILL.md}"
  ).select { |path| File.file?(path) }
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
