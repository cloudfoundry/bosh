RSpec.configure do |config|
  require 'rspec/core/formatters/console_codes'

  if ENV['DEFAULT_UPDATE_STRATEGY'] == 'duplicate-and-replace-vm'
    warning = 'Skipping non-hotswap tests'
    puts RSpec::Core::Formatters::ConsoleCodes.wrap(warning, :yellow)
    config.filter_run_excluding no_hotswap: true
  else
    warning = 'Skipping hotswap tests'
    puts RSpec::Core::Formatters::ConsoleCodes.wrap(warning, :yellow)
    config.filter_run_excluding hotswap: true
  end
end
