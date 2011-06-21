module Bosh::Director
  class EventLog < Logger

    def initialize(id, file)
      @id = id
      super(file)
    end

    def format_message(level, time, progname, msg)
      "{time => #{time.to_i}, #{msg}}\n"
    end

    def progress_log(stage, msg, index, total)
      info("id => #{@id}, stage => #{stage}, msg => #{msg}, current => #{index}, total => #{total}")
    end
  end
end
