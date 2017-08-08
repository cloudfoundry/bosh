module Bosh::Director
  class Errand::ResultSet
    def initialize(results)
      @results = results
    end

    def summary
      "#{counts_for(:successful?)} succeeded, #{counts_for(:errored?)} errored, #{counts_for(:cancelled?)} canceled, #{counts_for(:skipped?)} skipped"
    end

    private

    def counts_for(method)
      @results.count{ |r| r.send(method) }
    end
  end
end
