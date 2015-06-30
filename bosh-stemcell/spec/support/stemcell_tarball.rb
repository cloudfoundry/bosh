RSpec.configure do |config|
  unless ENV['STEMCELL_WORKDIR']
    warning = 'All stemcell_tarball tests are being skipped. STEMCELL_WORKDIR needs to be set'
    puts RSpec::Core::Formatters::ConsoleCodes.wrap(warning, :yellow)
    config.filter_run_excluding stemcell_tarball: true
  end
end
