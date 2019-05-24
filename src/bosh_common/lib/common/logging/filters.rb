require 'common/logging/regex_filter'

module Bosh::Common::Logging
  def self.null_query_filter
    Bosh::Common::Logging::RegexFilter.new(
      [
        { /^\(\d+\.\d+s\) \(conn: \d+\) SELECT NULL$/ => nil },
      ],
    )
  end

  def self.query_redaction_filter
    Bosh::Common::Logging::RegexFilter.new(
      [
        { /^(\(\d+\.\d+s\) \(conn: \d+\) (INSERT INTO ("|`).*?("|`)|UPDATE ("|`).*?("|`)|DELETE FROM ("|`).*?("|`))).+/m => '\1 <redacted>' },
      ],
    )
  end
end
