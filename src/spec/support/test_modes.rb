RSpec.configure do |config|
  require 'rspec/core/formatters/console_codes'

  if ENV['DEFAULT_UPDATE_VM_STRATEGY'] == 'create-swap-delete'
    warning = 'Skipping non-create-swap-delete tests'
    puts RSpec::Core::Formatters::ConsoleCodes.wrap(warning, :yellow)
    config.filter_run_excluding no_create_swap_delete: true
  else
    warning = 'Skipping create-swap-delete tests'
    puts RSpec::Core::Formatters::ConsoleCodes.wrap(warning, :yellow)
    config.filter_run_excluding create_swap_delete: true
  end

  if ENV['SKIP_RUN_SCRIPT_ENV'] == 'true'
    warning = 'Skipping tests using env params to run_script'
    puts RSpec::Core::Formatters::ConsoleCodes.wrap(warning, :yellow)
    config.filter_run_excluding run_script_env: true
  end
end
