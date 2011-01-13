module Bosh
  module Dashboard

    class DashboardError < StandardError
      def self.error_code(code = nil)
        define_method(:error_code) { code }
      end
    end

    class DirectorMissing      < DashboardError; error_code(102); end
    class DirectorInaccessible < DashboardError; error_code(103); end

    class DirectorError        < DashboardError; error_code(201); end
    class AuthError            < DirectorError; error_code(202); end
  end
end
