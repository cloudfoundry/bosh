module VimSdk
  class SoapException < Exception

    attr_reader :fault

    def initialize(message, fault)
      super(message)
      @fault = fault
    end

  end
end