require 'common/logging/regex_filter'

module Bosh::Common::Logging
  def self.default_filters
    [
      Bosh::Common::Logging::RegexFilter.new(
        [
          /^\(\d+\.\d+s\) SELECT NULL$/,
          /^\(\d+\.\d+s\) INSERT INTO/,
          /^\(\d+\.\d+s\) UPDATE ".*"/,
        ],
      ),
    ]
  end
end
