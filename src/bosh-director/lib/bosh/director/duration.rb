module Bosh::Director
  module Duration

    def duration(delta)
      seconds = delta % 60
      delta = (delta / 60).floor
      minutes = delta % 60
      delta = (delta / 60).floor
      hours = delta % 24
      delta = (delta / 24).floor
      days = delta

      result = []

      duration_helper(days, result, "day")
      duration_helper(hours, result, "hour")
      duration_helper(minutes, result, "minute")
      duration_helper(seconds, result, "second")

      result << "0 seconds" if result.empty?

      result.join(" ")
    end

    def duration_helper(value, result, unit)
      if value > 0
        result << "#{value} #{value == 1 ? unit : "#{unit}s"}"
      end
    end

    module_function :duration, :duration_helper

  end
end
