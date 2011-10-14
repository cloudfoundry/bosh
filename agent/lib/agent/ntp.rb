module Bosh::Agent
  class NTP
    NTPDATE = "/var/vcap/bosh/log/ntpdate.out"
    BAD_SERVER = "bad ntp server"
    FILE_MISSING = "file missing"
    BAD_CONTENTS = "bad file contents"

    def self.offset(ntpdate=NTPDATE)
      result = {}
      if File.exist?(ntpdate)
        lines = []
        File.open(ntpdate) do |file|
          lines = file.readlines
        end
        case lines.last
        when /^(.+)\s+ntpdate.+offset\s+(-*\d+\.\d+)/
          result["timestamp"] = $1
          result["offset"] = $2
        when /no server suitable for synchronization found/
          result["message"] = BAD_SERVER
        else
          result["message"] = BAD_CONTENTS
        end
      else
        result["message"] = FILE_MISSING
      end
      result
    end

  end
end
