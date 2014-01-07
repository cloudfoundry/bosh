namespace :stemcell do
  desc 'Create light stemcell from existing stemcell'
  task :build_light, [:stemcell_path] do |_,args|
    require 'bosh/stemcell/aws/light_stemcell'
    stemcell = Bosh::Stemcell::Archive.new(args.stemcell_path)
    light_stemcell = Bosh::Stemcell::Aws::LightStemcell.new(stemcell)
    light_stemcell.write_archive
  end

  desc 'Build a stemcell for the given :infrastructure, :operating_system and :agent_name and copy to ./tmp/'
  task :build, [:infrastructure_name, :operating_system_name, :agent_name] do |_, args|
    require 'bosh/dev/stemcell_builder'

    stemcell_builder = Bosh::Dev::StemcellBuilder.for_candidate_build(
      args.infrastructure_name, args.operating_system_name, args.agent_name)
    stemcell_path = stemcell_builder.build_stemcell

    mkdir_p('tmp')
    cp(stemcell_path, File.join('tmp', File.basename(stemcell_path)))
  end
end
