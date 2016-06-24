require 'net/http'

module Bosh::Director::Jobs
  module Helpers
    class DeepHashReplacement
      def self.replacement_map(obj)
        result = []
        create_replacement_map(result, obj)

        result
      end

      private

      def self.create_replacement_map(result, obj, path = nil)
        if obj.is_a? Array
          obj.each_with_index do |item, index|
            new_path = path.nil? ? [] : Bosh::Common::DeepCopy.copy(path)
            new_path << index
            create_replacement_map(result, item, new_path)
          end
        elsif obj.is_a? Hash
          obj.each do |key, value|
            new_path = path.nil? ? [] : Bosh::Common::DeepCopy.copy(path)
            new_path << key
            create_replacement_map(result, value, new_path)
          end
        else
          path ||= []
          if obj.to_s.match(/^\(\(.*\)\)$/)
            key_name = obj.gsub(/(^\(\(|\)\)$)/, '')
            result << {'key' => key_name, 'path' => path}
          end
        end
      end
    end
  end
end
