# Copyright (c) 2009-2012 VMware, Inc.

module BoshExtensions

  def say(message, sep = "\n")
    return unless Bosh::Cli::Config.output && message
    message = message.dup.to_s
    sep = "" if message[-1..-1] == sep
    Bosh::Cli::Config.output.print("#{$indent}#{message}#{sep}")
  end

  def with_indent(indent)
    old_indent, $indent = $indent, old_indent.to_s + indent.to_s
    yield
  ensure
    $indent = old_indent
  end

  def header(message, filler = '-')
    say("\n")
    say(message)
    say(filler.to_s * message.size)
  end

  def nl(count = 1)
    say("\n" * count)
  end

  def err(message)
    raise Bosh::Cli::CliExit.new message
  end

  def quit(message = nil)
    say(message)
    raise Bosh::Cli::GracefulExit, message
  end

  def blank?
    self.to_s.blank?
  end

  def pretty_size(what, prec=1)
    if what.is_a?(String) && File.exists?(what)
      size = File.size(what)
    else
      size = what.to_i
    end

    return "NA" unless size
    return "#{size}B" if size < 1024
    return sprintf("%.#{prec}fK", size/1024.0) if size < (1024*1024)
    if size < (1024*1024*1024)
      return sprintf("%.#{prec}fM", size/(1024.0*1024.0))
    end
    sprintf("%.#{prec}fG", size/(1024.0*1024.0*1024.0))
  end

  def pluralize(number, singular, plural = nil)
    plural = plural || "#{singular}s"
    number == 1 ? "1 #{singular}" : "#{number} #{plural}"
  end

  def format_time(time)
    ts = time.to_i
    sprintf("%02d:%02d:%02d", ts / 3600, (ts / 60) % 60, ts % 60);
  end

  def load_yaml_file(path, expected_type = Hash)
    err("Cannot find file `#{path}'") unless File.exists?(path)
    yaml = YAML.load_file(path)

    if expected_type && !yaml.is_a?(expected_type)
      err("Incorrect file format in `#{path}', #{expected_type} expected")
    end

    Bosh::Cli::YamlHelper.check_duplicate_keys(path)

    yaml
  rescue SystemCallError => e
    err("Cannot load YAML file at `#{path}': #{e}")
  end

  def dump_yaml_to_file(obj, file)
    yaml = YAML.dump(obj)
    file.write(yaml.gsub(" \n", "\n"))
    file.flush
  end
end

module BoshStringExtensions

  COLOR_CODES = {
    :red => "\e[0m\e[31m",
    :green => "\e[0m\e[32m",
    :yellow => "\e[0m\e[33m"
  }

  def red
    colorize(:red)
  end

  def green
    colorize(:green)
  end

  def yellow
    colorize(:yellow)
  end

  def colorize(color_code)
    if Bosh::Cli::Config.output &&
       Bosh::Cli::Config.output.tty? &&
       Bosh::Cli::Config.colorize &&
       COLOR_CODES[color_code]

      "#{COLOR_CODES[color_code]}#{self}\e[0m"
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
