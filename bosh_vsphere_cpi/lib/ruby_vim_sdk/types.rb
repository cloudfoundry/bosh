module VimSdk

  class SoapBinary < String; end

  class SoapBoolean
    attr_accessor :value
    def initialize(value)
      @value = value
    end
  end

  class SoapFloat < DelegateClass(Float); end
  class SoapInteger < DelegateClass(Integer); end

  class SoapByte < SoapInteger; end
  class SoapDouble < SoapFloat; end
  class SoapLong < SoapInteger; end
  class SoapShort < SoapInteger; end
  class SoapURI < String; end
  class SoapEnum; end

end