module Bosh::Director
  class BaseCloudCheck
    def initialize(logger, job)
      @logger = logger
      @job = job #we'll need this to checkpoint the task (cancel)
    end

    def json_encode(data)
      Yajl::Encoder.encode(data)
    end

    def json_decode(data)
      Yajl::Parser.parse(data)
    end
  end
end
