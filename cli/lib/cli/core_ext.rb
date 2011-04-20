module BoshExtensions
  def say(message, sep = "\n")
    return unless Bosh::Cli::Config.output && message
    message = message.dup.to_s
    sep = "" if message[-1..-1] == sep
    Bosh::Cli::Config.output.print("#{$indent}#{message}#{sep}")
  end

  def with_indent(indent, &block)
    old_indent, $indent = $indent, old_indent.to_s + indent.to_s
    yield
  ensure
    $indent = old_indent
  end

  def header(message, filler = '-')
    say "\n"
    say message
    say filler.to_s * message.size
  end

  def nl
    say("\n")
  end

  def err(message)
    raise Bosh::Cli::CliExit, message
  end

  def quit(message = nil)
    say message
    raise Bosh::Cli::GracefulExit, message
  end

  def blank?
    self.to_s.blank?
  end

  def pretty_size(what, prec=1)
    size = \
    if what.is_a?(String) && File.exists?(what)
      File.size(what)
    else
      what.to_i
    end

    return 'NA' unless size
    return "#{size}B" if size < 1024
    return sprintf("%.#{prec}fK", size/1024.0) if size < (1024*1024)
    return sprintf("%.#{prec}fM", size/(1024.0*1024.0)) if size < (1024*1024*1024)
    return sprintf("%.#{prec}fG", size/(1024.0*1024.0*1024.0))
  end
end

module BoshStringExtensions
  def red
    colorize("\e[0m\e[31m")
  end

  def green
    colorize("\e[0m\e[32m")
  end

  def yellow
    colorize("\e[0m\e[33m")
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
