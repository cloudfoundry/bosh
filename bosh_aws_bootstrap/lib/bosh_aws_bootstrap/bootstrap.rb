module Bosh
  module Aws
    class Bootstrap
      AWS_JENKINS_BUCKET = "bosh-jenkins-artifacts"

      attr_accessor :options, :runner

      def initialize(runner, options)
        self.options = options
        self.runner = runner
      end

      def create_user(username, password)
        user = Bosh::Cli::Command::User.new(runner)
        user.options = self.options
        user.create(username, password)
        login(username, password)
      end

      def login(username, password)
        misc = Bosh::Cli::Command::Misc.new(runner)
        misc.options = self.options
        misc.login(username, password)
      end

      def manifest
        raise NotImplementedError
      end
    end
  end
end