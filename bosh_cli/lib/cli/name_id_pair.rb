module Bosh::Cli

  class NameIdPair
    def self.parse(str)
      raise ArgumentError, 'str must not be nil' if str.nil?

      name, _, id = str.rpartition('/')
      if name.empty? || id.empty?
        raise ArgumentError, "\"#{str}\" must be in the form name/id"
      end

      new(name, id)
    end

    attr_reader :name, :id

    def initialize(name, id)
      @name, @id = name, id
    end
  end

end
