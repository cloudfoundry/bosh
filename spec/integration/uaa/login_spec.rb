require 'spec_helper'

describe "Logging into a director with UAA authentication", type: :integration do
  with_reset_sandbox_before_each(user_authentication: 'uaa')
  it "shows the right prompts" do
    bosh_runner.run("target #{current_sandbox.director_url}")

    output = bosh_runner.run_interactively("login") do |terminal|
      terminal.wait_for_output("Email:")
      terminal.send_input("admin")
      terminal.wait_for_output("Password:")
      terminal.send_input("admin")
      terminal.wait_for_output("One Time Code")
      terminal.send_input("myfancycode")
    end

    # expect(output).to include("Logged in")
  end
end
