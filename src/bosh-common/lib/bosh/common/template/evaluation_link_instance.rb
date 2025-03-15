require 'bosh/common/template/property_helper'

module Bosh::Common
  module Template
    class EvaluationLinkInstance
      include PropertyHelper

      attr_reader :name
      attr_reader :index
      attr_reader :id
      attr_reader :az
      attr_reader :address
      attr_reader :properties
      attr_reader :bootstrap

      def initialize(name, index, id, az, address, properties, bootstrap)
        @name = name
        @index = index
        @id = id
        @az = az
        @address = address
        @properties = properties
        @bootstrap = bootstrap
      end

      def p(*args)
        names = Array(args[0])

        names.each do |name|
          result = lookup_property(@properties, name)
          return result unless result.nil?
        end

        return args[1] if args.length == 2

        raise UnknownProperty, names
      end

      def if_p(*names)
        values = names.map do |name|
          value = lookup_property(@properties, name)
          return Template::EvaluationContext::ActiveElseBlock.new(self) if value.nil?

          value
        end

        yield(*values)
        Template::EvaluationContext::InactiveElseBlock.new
      end
    end
  end
end
