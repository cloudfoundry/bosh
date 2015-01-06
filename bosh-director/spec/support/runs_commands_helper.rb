def runs(o, command)
  command_runner = double('command runner')
  o.command_runner = command_runner
  expect(command_runner).to receive(:sh).with(command)
end
