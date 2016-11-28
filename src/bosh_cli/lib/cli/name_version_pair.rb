module Bosh::Cli

  class NameVersionPair
    def self.parse(str)
      raise ArgumentError, 'str must not be nil' if str.nil?
      #raise ArgumentError, 'str must not be empty' if str.empty?

      name, _, version = str.rpartition('/')
      if name.empty? || version.empty?
        raise ArgumentError, "\"#{str}\" must be in the form name/version"
      end

      new(name, version)
    end

    attr_reader :name, :version

    def initialize(name, version)
      @name, @version = name, version
    end
  end

end
