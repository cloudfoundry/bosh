require_relative '../spec_helper'

describe 'cli: status', type: :integration do
  with_reset_sandbox_before_each

  it 'shows status', no_reset: true do
    _, exit_code = bosh_runner.run('env', return_exit_code: true, failure_expected: true)
    expect(exit_code).to(eq(1))
  end
end
