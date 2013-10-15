def runs(o, command)
  command_runner = double('command runner')
  o.command_runner = command_runner
  command_runner.should_receive(:sh).with(command)
end
