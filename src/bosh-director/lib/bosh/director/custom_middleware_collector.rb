require 'prometheus/middleware/collector'

module Bosh
  module Director
    class CustomMiddlewareCollector < Prometheus::Middleware::Collector
      def strip_ids_from_path(path)
        path
          .gsub(%r{/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}(/|$)}, '/:uuid\\1')
          .gsub(%r{/\d+(/|$)}, '/:id\\1')
          .gsub(%r{/deployments/[a-z0-9_-]+(/|$)}, '/deployments/:deployment\\1')
      end
    end
  end
end
