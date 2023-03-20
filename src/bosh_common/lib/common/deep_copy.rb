module Bosh::Common
  module DeepCopy
    def self.copy(object)
      deep_copy(object)
    end

    def self.deep_copy(object)
      if object.is_a?(Hash)
        result = object.clone
        object.each{|k, v| result[k] = self.deep_copy(v)}
        result
      elsif object.is_a?(Array)
        result = object.clone
        result.clear
        object.each{|v| result << self.deep_copy(v)}
        result
      else
        object.clone
      end
    end
  end
end
