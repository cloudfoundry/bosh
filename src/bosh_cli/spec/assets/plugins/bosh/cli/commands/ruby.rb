module Bosh::Cli::Command
  class Ruby < Base

    command :ruby_version do
      usage "ruby version"
      desc "Say ruby version"
      route :ruby, :ruby_version
    end

    command :ruby_config do
      usage "ruby config <string>"
      desc "Query rbconfig"
      route :ruby, :ruby_config
    end

    def ruby_version
      say(RUBY_VERSION)
    end

    def ruby_config(string)
      say(::Config::CONFIG[string])
    end
  end
end
