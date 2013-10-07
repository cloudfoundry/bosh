module VimSdk

  class TypedArray < Array
    class << self
      attr_accessor :item
    end
  end

end