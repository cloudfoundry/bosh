module Bosh
  module Template
    class EvaluationLink
      include PropertyHelper

      attr_reader :instances
      attr_reader :properties

      def initialize(instances, properties)
        @instances = instances
        @properties = properties
      end

      def p(*args)
        names = Array(args[0])

        names.each do |name|
          result = lookup_property(@properties, name)
          return result unless result.nil?
        end

        return args[1] if args.length == 2
        raise UnknownProperty.new(names)
      end

      def if_p(*names)
        values = names.map do |name|
          value = lookup_property(@properties, name)
          return Bosh::Template::EvaluationContext::ActiveElseBlock.new(self) if value.nil?
          value
        end

        yield *values
        Bosh::Template::EvaluationContext::InactiveElseBlock.new
      end
    end
  end
end