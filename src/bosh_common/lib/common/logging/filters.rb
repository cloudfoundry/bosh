require 'common/logging/regex_filter'

module Bosh::Common::Logging
  def self.default_filters
    [
      Bosh::Common::Logging::RegexFilter.new(
        [
          { /^\(\d+\.\d+s\) \(conn: \d+\) SELECT NULL$/ => nil },
          { /^(\(\d+\.\d+s\) \(conn: \d+\) (INSERT INTO "[^"]+"|UPDATE "[^"]+"|DELETE FROM "[^"]+")).+/m => '\1 <redacted>' },
        ],
      ),
    ]
  end
end
