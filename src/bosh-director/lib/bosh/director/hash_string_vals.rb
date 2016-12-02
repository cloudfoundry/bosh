module Bosh::Director

  module_function

  # Replace values for keys in a hash with their to_s.
  def hash_string_vals(h, *keys)
    keys.each do |k|
      h[k] = h[k].to_s
    end
    h
  end

end
