module VimSdk::VmodlHelper
  UNDERSCORE_EXCEPTIONS = {
    "numCPUs" => "num_cpus",
    "importVApp" => "import_vapp"
  }

  # Borrowed mostly from activesupport
  def camelize(word)
    word.gsub(/(?:^|_)(.)/) { $1.upcase }
  end

  # Borrowed mostly from activesupport
  def underscore(word)
    exception = UNDERSCORE_EXCEPTIONS[word]
    return exception if exception

    word = word.dup
    word.gsub!(/([A-Z]+)([A-Z][a-z])/,'\1_\2')
    word.gsub!(/([a-z\d])([A-Z])/,'\1_\2')
    word.downcase!
    word
  end

  def vmodl_type_to_ruby(name)
    name.split(".").collect { |part| camelize(part) }.join(".")
  end

  def vmodl_property_to_ruby(name)
    underscore(name)
  end

  module_function :camelize, :underscore, :vmodl_type_to_ruby, :vmodl_property_to_ruby
end