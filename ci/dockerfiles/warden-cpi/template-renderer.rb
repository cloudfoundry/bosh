require "rubygems"
require "ostruct"
require "json"
require "erb"
require "yaml"

class Hash
  def recursive_merge!(other)
    merge!(other) do |_, old_value, new_value|
      if old_value.instance_of?(Hash) && new_value.instance_of?(Hash)
        old_value.recursive_merge!(new_value)
      else
        new_value
      end
    end

    self
  end
end

class TemplateEvaluationContext
  attr_reader :name, :index
  attr_reader :properties, :raw_properties
  attr_reader :spec

  def initialize(spec)
    @name = spec["job"]["name"] if spec["job"].is_a?(Hash)
    @index = spec["index"]

    properties1 =
      if !spec["job_properties"].nil?
        spec["job_properties"]
      else
        spec["global_properties"].recursive_merge!(spec["cluster_properties"])
      end

    properties = {}
    spec["default_properties"].each do |name, value|
      copy_property(properties, properties1, name, value)
    end

    @properties = open_struct(properties)
    @raw_properties = properties
    @spec = open_struct(spec)
  end

  def get_binding
    binding
  end

  def p(*args)
    names = Array(args[0])

    names.each do |name|
      result = lookup_property(@raw_properties, name)
      return result unless result.nil?
    end

    return args[1] if args.length == 2
    raise UnknownProperty.new(names)
  end

  def if_p(*names)
    values = names.map do |name|
      value = lookup_property(@raw_properties, name)
      return ActiveElseBlock.new(self) if value.nil?

      value
    end

    yield(*values)

    InactiveElseBlock.new
  end

  def if_link(_name)
    false
  end

  private

  def copy_property(dst, src, name, default = nil)
    keys = name.split(".")
    src_ref = src
    dst_ref = dst

    keys.each do |key|
      src_ref = src_ref[key]
      break if src_ref.nil? # no property with this name is src
    end

    keys[0..-2].each do |key|
      dst_ref[key] ||= {}
      dst_ref = dst_ref[key]
    end

    dst_ref[keys[-1]] ||= {}
    dst_ref[keys[-1]] = src_ref.nil? ? default : src_ref
  end

  def open_struct(object)
    case object
    when Hash
      mapped = object.each_with_object({}) { |(k, v), h| h[k] = open_struct(v) }
      OpenStruct.new(mapped)
    when Array
      object.map { |item| open_struct(item) }
    else
      object
    end
  end

  def lookup_property(collection, name)
    keys = name.split(".")
    ref = collection

    keys.each do |key|
      ref = ref[key]
      return nil if ref.nil?
    end

    ref
  end

  class UnknownProperty < StandardError
    attr_reader :name

    def initialize(names)
      @names = names
      super("Can't find property '#{names.join("', or '")}'")
    end
  end

  class ActiveElseBlock
    def initialize(template)
      @context = template
    end

    def else
      yield
    end

    def else_if_p(*names, &block)
      @context.if_p(*names, &block)
    end
  end

  class InactiveElseBlock
    def else
    end

    def else_if_p(*_names)
      InactiveElseBlock.new
    end
  end
end

# todo do not use JSON in releases
class << JSON
  alias_method :dump_array_or_hash, :dump

  def dump(*args)
    arg = args[0]
    if arg.is_a?(String) || arg.is_a?(Numeric)
      arg.inspect
    else
      dump_array_or_hash(*args)
    end
  end
end

class ERBRenderer
  def initialize(context)
    @context = context
  end

  def render(src_path, dst_path)
    erb = ERB.new(File.read(src_path), trim_mode: "-")
    erb.filename = src_path

    File.write(dst_path, erb.result(@context.get_binding))

  rescue Exception => e # rubocop:disable Lint/RescueException
    name = "#{@context.name}/#{@context.index}"

    line_i = e.backtrace&.index { |l| l.include?(erb.filename) }
    line_num = line_i ? e.backtrace[line_i].split(":")[1] : "unknown"
    location = "(line #{line_num}: #{e.inspect})"

    raise("Error filling in template '#{src_path}' for #{name} #{location}")
  end
end

if $PROGRAM_NAME == __FILE__
  context_path, src_path, dst_path = *ARGV

  context_hash = JSON.parse(File.read(context_path))
  context = TemplateEvaluationContext.new(context_hash)

  renderer = ERBRenderer.new(context)
  renderer.render(src_path, dst_path)
end
