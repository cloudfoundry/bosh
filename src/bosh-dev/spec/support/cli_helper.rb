module CliHelper
  def exec_cmd(cmd)
    logger.info("Executing: #{cmd}")
    stdout, stderr, status = Open3.capture3(cmd)
    raise "Failed executing '#{cmd}'\nSTDOUT: '#{stdout}', \nSTDERR: '#{stderr}'" unless status.success?
    [stdout, stderr, status]
  end

  def config_git_user
    exec_cmd('git config --local user.email "fake@example.com"')
    exec_cmd('git config --local user.name "Fake User"')
  end
end

RSpec.configure do |c|
  c.include(CliHelper)
end
