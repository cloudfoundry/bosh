RSpec.configure do |config|
  unless ENV['STEMCELL_WORKDIR']
    warning = 'All STEMCELL_WORKDIR tests are being skipped. ENV["STEMCELL_WORKDIR"] must be set to test stemcell tarball'
    puts RSpec::Core::Formatters::ConsoleCodes.wrap(warning, :yellow)
    config.filter_run_excluding stemcell_tarball: true
  end
end
