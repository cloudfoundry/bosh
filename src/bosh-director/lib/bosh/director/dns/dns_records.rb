module Bosh::Director
  class DnsRecords
    attr_reader :records, :version

    def initialize(records = [], version = 0)
      @records = records
      @version = version
    end

    def to_json
      {:records => @records, :version => @version}.to_json
    end
  end
end