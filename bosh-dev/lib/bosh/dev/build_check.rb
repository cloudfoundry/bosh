require 'jenkins_api_client'

module Bosh::Dev
  class BuildCheck
    def initialize(jenkins_client, job_name)
      @jenkins_client = jenkins_client
      @job_name = job_name
    end

    def failing?
      build_color.start_with?('red')
    end

    private

    attr_reader :jenkins_client
    attr_reader :job_name

    def build_color
      jenkins_client.job.list_details(job_name)['color']
    end
  end
end