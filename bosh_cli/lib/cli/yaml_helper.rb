# Copyright (c) 2009-2012 VMware, Inc.

module Bosh::Cli
  class YamlHelper
    class << self
      private
      def process_object(o)
        case o
          when Psych::Nodes::Mapping
            process_mapping(o)
          when Psych::Nodes::Sequence
            process_sequence(o)
          when Psych::Nodes::Scalar
            # noop
          when Psych::Nodes::Alias
            # noop
          else
            err("Unhandled class #{o.class}, fix yaml duplicate check")
        end
      end

      def process_sequence(s)
        s.children.each do |v|
          process_object(v)
        end
      end

      def process_mapping(m)
        return unless m.children
        s = Set.new

        m.children.each_with_index do |key_or_value, index|
          next if index.odd? # skip the values
          key = key_or_value.value # Sorry this is confusing, Psych mappings don't behave nicely like maps
          raise "Found duplicate key '#{key}'" if s.include?(key)
          s.add(key)
        end

        m.children.each_with_index do |key_or_value, index|
          next if index.even? # skip the keys
          process_object(key_or_value)
        end
      end

      public

      def check_duplicate_keys(yaml_str)
        document = Psych.parse(yaml_str)
        process_mapping(document.root) if document
      end
    end
  end
end
