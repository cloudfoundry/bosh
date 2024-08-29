require 'bosh/director'

module Bosh::Director
  module Test
    module TaskHelpers
      def expect_redirect_to_queued_task(response)
        expect(response).to be_redirect

        match = response.location.match(%r{/tasks/(\d+)})
        expect(match).to_not be_nil

        task_id = match[1]
        task = Bosh::Director::Models::Task[task_id]
        expect(task.state).to eq('queued')
        task
      end

      def make_task_with_team(attributes)
        teams = attributes.delete(:teams)
        task = FactoryBot.create(:models_task, attributes)
        task.teams = teams
        task
      end
    end
  end
end

RSpec.configure do |config|
  config.include(Bosh::Director::Test::TaskHelpers)
end
