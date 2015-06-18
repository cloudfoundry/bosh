require 'spec_helper'

describe 'cli: login using the directors built-in user DB', type: :integration do
  with_reset_sandbox_before_each

  context 'interactively' do
    it 'can log in' do
      bosh_runner.run("target #{current_sandbox.director_url}")

      bosh_runner.run_interactively('login') do |runner|
        expect(runner).to have_output 'username:'
        runner.send_keys 'test'
        expect(runner).to have_output 'password:'
        runner.send_keys 'test'
        expect(runner).to have_output 'Logged in'
      end
    end
  end

  it 'requires login when talking to director' do
    expect(bosh_runner.run('properties', failure_expected: true)).to match(/please choose target first/i)
    bosh_runner.run("target #{current_sandbox.director_url}")
    expect(bosh_runner.run('properties', failure_expected: true)).to match(/please log in first/i)
  end

  it 'cannot log in if password is invalid' do
    bosh_runner.run("target #{current_sandbox.director_url}")
    expect_output('login test admin', <<-OUT)
        Cannot log in as `test'
    OUT
  end
end
