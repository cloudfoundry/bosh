require 'spec_helper'

describe 'cli: login using the directors built-in user DB', type: :integration do
  context 'when users specified in manifest' do
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

  context 'when users are not specified in manifest' do
    with_reset_sandbox_before_each(users_in_manifest: false)

    it 'can log in as a default user, create another user and delete created user' do
      bosh_runner.run("target #{current_sandbox.director_url}")
      bosh_runner.run('login admin admin')
      expect(bosh_runner.run('create user john john-pass')).to match(/User `john' has been created/i)

      expect(bosh_runner.run('login john john-pass')).to match(/Logged in as `john'/i)
      expect(bosh_runner.run('create user jane jane-pass')).to match(/user `jane' has been created/i)
      bosh_runner.run('logout')

      expect(bosh_runner.run('login jane jane-pass')).to match(/Logged in as `jane'/i)
      expect(bosh_runner.run('delete user john')).to match(/User `john' has been deleted/i)
      bosh_runner.run('logout')

      expect(bosh_runner.run('login john john-pass', failure_expected: true)).to match(/Cannot log in as `john'/i)
      expect(bosh_runner.run('login jane jane-pass')).to match(/Logged in as `jane'/i)
    end
  end
end
