require 'bosh/director'

module Bosh::Director
  module Test
    module TaskHelpers
      def expect_redirect_to_queued_task(response)
        response.should be_redirect
        (last_response.location =~ /\/tasks\/(\d+)/).should_not be_nil

        new_task = Models::Task[$1]
        new_task.state.should == 'queued'
        new_task
      end
    end
  end
end
