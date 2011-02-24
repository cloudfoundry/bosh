module BoshExtensions
  def say(message)
    Bosh::Cli::Config.output.puts(message) if Bosh::Cli::Config.output
  end

  def header(message, filler = '-')
    say "\n"
    say message
    say filler.to_s * message.size
  end

  def err(message)
    raise Bosh::Cli::CliExit, message
  end

  def quit(message = nil)
    raise Bosh::Cli::GracefulExit, message
  end

  def blank?
    self.to_s.blank?
  end
end

module BoshStringExtensions
  def red
    colorize("\e[0m\e[31m")
  end

  def green
    colorize("\e[0m\e[32m")
  end

  def colorize(color_code)
    if Bosh::Cli::Config.colorize
      "#{color_code}#{self}\e[0m"
    else
      self
    end
  end

  def blank?
    self =~ /^\s*$/
  end

  def bosh_valid_id?
    self =~ Bosh::Cli::Config::VALID_ID
  end

  def truncate(limit = 30)
    return "" if self.blank?
    etc = "..."
    stripped = self.strip[0..limit]
    if stripped.length > limit
      stripped.gsub(/\s+?(\S+)?$/, "") + etc
    else
      stripped
    end
  end

end

class Object
  include BoshExtensions
end

class String
  include BoshStringExtensions
end
