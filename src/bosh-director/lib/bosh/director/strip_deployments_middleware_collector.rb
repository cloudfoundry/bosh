require 'prometheus/middleware/collector'

module Bosh
  module Director
    class StripDeploymentsMiddlewareCollector < Prometheus::Middleware::Collector
      def strip_ids_from_path(path)
        super(path)
          .gsub(%r{/deployments/[a-z0-9_-]+(/|$)}, '/deployments/:deployment\\1')
      end
    end
  end
end
