module Bosh::Director
  module DeploymentPlan
    class LinkInfo < Struct.new(:deployment_name, :spec); end
  end
end