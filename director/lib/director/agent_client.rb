module Bosh::Director
  class AgentClient < Client

    def initialize(*args)
      super("agent", *args)
    end

  end
end