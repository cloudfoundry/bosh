module Bosh::Director
  class EventLog < Logger

    def initialize(id, file)
      @id = id
      super(file)
    end

    def format_message(level, time, progname, msg)
      msg + "\n"
    end

    def progress_log(stage, msg, index, total)
      progress = {:time     => Time.now.to_i,
                  :id       => @id,
                  :stage    => stage,
                  :msg      => msg,
                  :current  => index,
                  :total    => total}
      info Yajl::Encoder.encode(progress)
    end
  end
end
