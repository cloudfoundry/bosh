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

module ColorizeOutput

  def red
    colorize(self, "\e[0m\e[31m")
  end

  def green
    colorize(self, "\e[0m\e[32m")    
  end

  def colorize(text, color_code)
    if Bosh::Cli::Config.colorize
      "#{color_code}#{text}\e[0m"
    else
      text
    end
  end
  
end

class Object
  include BoshExtensions
end

class String
  include ColorizeOutput
end
