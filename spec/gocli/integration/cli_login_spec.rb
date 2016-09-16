require_relative '../spec_helper'

describe 'cli: login using the directors built-in user DB', type: :integration do
  context 'when users specified in manifest' do
    with_reset_sandbox_before_each

    context 'interactively' do
      it 'can log in' do
        bosh_runner.run("env #{current_sandbox.director_url}")

        bosh_runner.run_interactively('log-in') do |runner|
          expect(runner).to have_output 'Username:'
          runner.send_keys 'test'
          expect(runner).to have_output 'Password:'
          runner.send_keys 'test'
          expect(runner).to have_output 'Logged in'
        end
      end
    end

    it 'requires login when talking to director' do
      expect(bosh_runner.run('tasks', include_credentials: false, failure_expected: true)).to match(/Expected non-empty Director URL/)
      bosh_runner.run("env #{current_sandbox.director_url}")
      expect(bosh_runner.run('tasks', include_credentials: false, failure_expected: true)).to match(/Not authorized/)
    end

    it 'cannot log in if password is invalid' do
      bosh_runner.run("env #{current_sandbox.director_url}")
      expect { bosh_runner.run('log-in', user: 'test', password: 'admin') }
        .to raise_error(RuntimeError, /Invalid credentials/)
    end
  end

  context 'when users are not specified in manifest' do
    with_reset_sandbox_before_each(users_in_manifest: false)

    it 'can log in as a default user, create another user and delete created user' do
      pending('cli2: #130549577: backport delete-user command')
      pending('cli2: #130549503: backport create-user command')

      bosh_runner.run("env #{current_sandbox.director_url}")
      bosh_runner.run('log-in', user: 'admin', password: 'admin')
      expect(bosh_runner.run('create-user john john-pass')).to match(/User 'john' has been created/)

      john_login_output = bosh_runner.run('log-in', user: 'john', password: 'john-pass')
      expect(john_login_output).to match(/Logged in/)
      expect(john_login_output).to match(/as user 'john'/)
      expect(bosh_runner.run('create-user jane jane-pass')).to match(/user 'jane' has been created/)
      bosh_runner.run('logout')

      jane_login_output = bosh_runner.run('log-in', user: 'jane', password: 'jane-pass')
      expect(jane_login_output).to match(/Logged in/)
      expect(jane_login_output).to match(/as user 'jane'/)
      expect(bosh_runner.run('delete-user john')).to match(/User 'john' has been deleted/)
      bosh_runner.run('logout')

      expect(bosh_runner.run('log-in', user: 'john', password: 'john-pass', failure_expected: true)).to match(/Invalid credentials/)
      jane_login_output = bosh_runner.run('log-in', user: 'jane', password: 'jane-pass')
      expect(jane_login_output).to match(/Logged in/)
      expect(jane_login_output).to match(/as user 'jane'/)
    end
  end
end
