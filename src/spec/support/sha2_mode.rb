RSpec.configure do |config|
  require 'rspec/core/formatters/console_codes'

  if ENV['SHA2_MODE'] == 'true'
    warning = 'Running cli commands with --sha2 flag, skipping tests with sha1 tag'
    puts RSpec::Core::Formatters::ConsoleCodes.wrap(warning, :yellow)
    config.filter_run_excluding sha1: true
  else
    warning = 'Skipping tests with sha2 tag'
    puts RSpec::Core::Formatters::ConsoleCodes.wrap(warning, :yellow)
    config.filter_run_excluding sha2: true
  end
end
