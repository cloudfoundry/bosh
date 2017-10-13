class ThreadFormatter
  FORMAT = "%s, [%s#%d] [%s] %5s -- %s: %s\n"

  # get pattern layout for Logging::Logger
  def self.layout
    Logging.layouts.pattern({
      :pattern => "%.1l, [%d #%p] [%T] %5l -- %c: %m\n",
      :date_pattern => "%Y-%m-%dT%H:%M:%S.%s"
    })
  end

  attr_accessor :datetime_format

  def initialize
    @datetime_format = nil
  end

  def call(severity, time, progname, msg)
    thread_name = Thread.current[:name] || "0x#{Thread.current.object_id.to_s(16)}"
    FORMAT % [severity[0..0], format_datetime(time), $$, thread_name, severity, progname,
              msg2str(msg)]
  end

  private

  def format_datetime(time)
    if @datetime_format.nil?
      time.strftime("%Y-%m-%dT%H:%M:%S.") << "%06d " % time.usec
    else
      time.strftime(@datetime_format)
    end
  end

  def msg2str(msg)
    case msg
      when ::String
        msg
      when ::Exception
        "#{ msg.message } (#{ msg.class })\n" <<
            (msg.backtrace || []).join("\n")
      else
        msg.inspect
    end
  end
end

module Kernel

  def with_thread_name(name)
    old_name = Thread.current[:name]
    Thread.current[:name] = name
    yield
  ensure
    Thread.current[:name] = old_name
  end

end
