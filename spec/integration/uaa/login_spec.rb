require 'spec_helper'

describe "Logging into a director with UAA authentication", type: :integration do
  with_reset_sandbox_before_each(user_authentication: 'uaa')

  it "shows the right prompts" do
    bosh_runner.run("target #{current_sandbox.director_url}")

    bosh_runner.run_interactively('login') do |runner|
      expect(runner).to have_output 'Email:'
      runner.send_keys 'admin'
      expect(runner).to have_output 'Password:'
      runner.send_keys 'admin'
      expect(runner).to have_output 'One Time Code'
      runner.send_keys 'myfancycode'
    end
  end
end
