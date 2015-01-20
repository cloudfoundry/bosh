require 'rspec/core/formatters/console_codes'

RSpec.configure do |config|
  if ENV['STEMCELL_TGZ'] && ENV['STEMCELL_TGZ_WORKDIR']
    config.before(:all) do
      Bosh::Core::Shell.new.run("sudo tar xf #{ENV['STEMCELL_TGZ']} -C #{ENV['STEMCELL_TGZ_WORKDIR']}")
    end

    config.after(:all) do
      FileUtils.rm_rf(ENV['STEMCELL_TGZ_WORKDIR']) if ENV['STEMCELL_TGZ'] && ENV['STEMCELL_TGZ_WORKDIR']
    end
  else
    warning = 'All STEMCELL_TGZ tests are being skipped.'\
              ' ENV["STEMCELL_TGZ"] and ENV["STEMCELL_TGZ_WORKDIR"] must be set to test stemcell tgz file'
    puts RSpec::Core::Formatters::ConsoleCodes.wrap(warning, :yellow)
    config.filter_run_excluding stemcell_tgz: true
  end
end
