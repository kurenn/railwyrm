# frozen_string_literal: true

require "pastel"
require "thor"
require "tty-font"
require "tty-prompt"
require "tty-spinner"

module Railwyrm
  class Error < StandardError; end
  class CommandFailed < Error; end
  class InvalidConfiguration < Error; end
end

require_relative "railwyrm/version"
require_relative "railwyrm/configuration"
require_relative "railwyrm/ui"
require_relative "railwyrm/shell"
require_relative "railwyrm/rails_blueprint"
require_relative "railwyrm/generator"
require_relative "railwyrm/recipe_schema"
require_relative "railwyrm/server"
require_relative "railwyrm/cli"
