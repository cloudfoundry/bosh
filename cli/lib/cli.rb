require "cli/version"
require "cli/config"
require "cli/errors"
require "cli/validation"
require "cli/cache"
require "cli/stemcell"
require "cli/release"
require "cli/deployment"
require "cli/user"
require "cli/api_client"
require "cli/director_task"

require "cli/runner"

module BoshExtensions
  def bosh_say(message)
    out = Bosh::Cli::Config.output
    puts message if out
  end
end

class Object
  include BoshExtensions
end
