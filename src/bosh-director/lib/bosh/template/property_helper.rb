require 'bosh/template/invalid_property_type'

module Bosh
  module Template
    module PropertyHelper
      # Copies property with a given name from src to dst.
      # @param [Hash] dst Property destination
      # @param [Hash] src Property source
      # @param [String] name Property name (dot-separated)
      # @param [Object] default Default value (if property is not in src)
      def copy_property(dst, src, name, default = nil)
        keys = name.split(".")
        src_ref = src
        dst_ref = dst

        keys.each do |key|
          unless src_ref.is_a?(Hash)
            raise Bosh::Template::InvalidPropertyType,
              "Property '#{name}' expects a hash, but received '#{src_ref.class}'"
          end
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

      # @param [Hash] collection Property collection
      # @param [String] name Dot-separated property name
      def lookup_property(collection, name)
        return nil if collection.nil?
        keys = name.split(".")
        ref = collection

        keys.each do |key|
          ref = ref[key]
          return nil if ref.nil?
        end

        ref
      end

      def sort_property(property)
        if property.is_a?(Hash)
          property.each do |k, v|
            property[k] = sort_property(v)
          end.sort.to_h
        else
          property
        end
      end

      # Inject property with a given name and value to dst.
      # @param [Hash] dst Property destination
      # @param [String] name Property name (dot-separated)
      # @param [Object] value Property value to be set
      def set_property(dst, name, value)
        keys = name.split('.')
        dst_ref = dst

        keys[0..-2].each do |key|
          dst_ref[key] ||= {}
          dst_ref = dst_ref[key]
        end

        dst_ref[keys[-1]] = value
      end

      def validate_properties_format(properties, name)
        keys = name.split('.')
        properties_ref = properties

        keys.each do |key|
          unless properties_ref.is_a?(Hash)
            raise Bosh::Template::InvalidPropertyType,
                  "Property '#{name}' expects a hash, but received '#{properties_ref.class}'"
          end
          properties_ref = properties_ref[key]
          break if properties_ref.nil? # no property with this name is src
        end
      end
    end
  end
end
