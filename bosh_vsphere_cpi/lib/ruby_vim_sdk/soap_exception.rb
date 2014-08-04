module VimSdk
  class SoapError < StandardError

    attr_reader :fault

    def initialize(message, fault)
      super(message)
      @fault = fault
    end

  end
end
