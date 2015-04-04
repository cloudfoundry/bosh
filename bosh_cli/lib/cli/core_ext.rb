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
    raise Bosh::Cli::CliError, message
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
    yaml_str = read_yaml_file(path)

    yaml = Psych::load(yaml_str)
    if expected_type && !yaml.is_a?(expected_type)
      err("Incorrect YAML structure in `#{path}': expected #{expected_type} at the root".make_red)
    end

    yaml
  end

  def read_yaml_file(path)
    err("Cannot find file `#{path}'".make_red) unless File.exist?(path)

    begin
      yaml_str = ERB.new(File.read(path)).result
    rescue SystemCallError => e
      err("Cannot load YAML file at `#{path}': #{e}".make_red)
    end

    begin
      Bosh::Cli::YamlHelper.check_duplicate_keys(yaml_str)
    rescue Exception => e # on ruby 1.9.3 Psych::SyntaxError isn't a StandardError
      err("Incorrect YAML structure in `#{path}': #{e}".make_red)
    end
    yaml_str
  end

  def write_yaml(manifest, path)
    File.open(path, "w+") do |f|
      f.write(manifest.to_yaml)
    end
  end

  # @return [Fixnum]
  def terminal_width
    STDIN.tty? ? [HighLine::SystemExtensions.terminal_size[0], 120].min : 80
  end

  def warning(message)
    warn("[WARNING] #{message}".make_yellow)
  end
end

module BoshStringExtensions

  COLOR_CODES = {
    :red => "\e[0m\e[31m",
    :green => "\e[0m\e[32m",
    :yellow => "\e[0m\e[33m"
  }

  def make_red
    make_color(:red)
  end

  def make_green
    make_color(:green)
  end

  def make_yellow
    make_color(:yellow)
  end

  def make_color(color_code)
    # invalid color
    return self if !COLOR_CODES[color_code]

    # output disabled
    return self if !Bosh::Cli::Config.output

    # colorization explicitly disabled
    return self if Bosh::Cli::Config.colorize == false

    # colorization explicitly enabled, or output is tty
    if Bosh::Cli::Config.colorize || Bosh::Cli::Config.output.tty?
      "#{COLOR_CODES[color_code]}#{self}\e[0m"
    else
      self
    end
  end

  def blank?
    self =~ /^\s*$/
  end

  def bosh_valid_id?
    !!(self =~ Bosh::Cli::Config::VALID_ID)
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

  def columnize(width = 80, left_margin = 0)
    Bosh::Cli::LineWrap.new(width, left_margin).wrap(self)
  end

  def indent(margin = 2)
    self.split("\n").map { |line|
      " " * margin + line
    }.join("\n")
  end

end

class Object
  include BoshExtensions
end

class String
  include BoshStringExtensions
end
