module Bosh::Common
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
      keys = name.split(".")
      ref = collection

      keys.each do |key|
        ref = ref[key]
        return nil if ref.nil?
      end

      ref
    end
  end
end
