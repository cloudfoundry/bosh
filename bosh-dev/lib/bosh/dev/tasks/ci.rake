require 'bosh/dev/build'
require 'bosh/dev/fog_bulk_uploader'

namespace :ci do
  desc "Publish CI pipeline gems to S3"
  task :publish_pipeline_gems do
    require 'bosh/dev/version_file'
    version_file = Bosh::Dev::VersionFile.new(Bosh::Dev::Build.current.number)
    version_file.write
    Rake::Task["all:finalize_release_directory"].invoke
    cd('pkg') do
      Bundler.with_clean_env do
      # We need to run this without Bundler as we generate an index for all dependant gems when run with bundler
        sh('gem', 'generate_index', '.')
      end
      Bosh::Dev::FogBulkUploader.s3_pipeline.upload_r('.', 'gems')
    end
  end

  desc "Publish CI pipeline MicroBOSH release to S3"
  task :publish_microbosh_release => [:publish_pipeline_gems] do
    require 'bosh/dev/micro_bosh_release'

    cd(ENV['WORKSPACE']) do
      release = Bosh::Dev::MicroBoshRelease.new
      Bosh::Dev::Build.current.upload(release)
    end
  end

  desc "Promote from pipeline to artifacts bucket"
  task :promote_artifacts do
    run('s3cmd sync s3://bosh-ci-pipeline/gems/ s3://bosh-jenkins-gems')
    run('s3cmd sync s3://bosh-ci-pipeline/release s3://bosh-jenkins-artifacts')
    run('s3cmd sync s3://bosh-ci-pipeline/bosh-stemcell s3://bosh-jenkins-artifacts')
    run('s3cmd sync s3://bosh-ci-pipeline/micro-bosh-stemcell s3://bosh-jenkins-artifacts')
    publish_latest_light_micro_bosh_stemcell_ami_text_file
  end

  def publish_latest_light_micro_bosh_stemcell_ami_text_file
    require 'aws-sdk'
    bucket_name = 'bosh-jenkins-artifacts'
    AWS.config({
                   access_key_id: ENV['AWS_ACCESS_KEY_ID_FOR_STEMCELLS_JENKINS_ACCOUNT'],
                   secret_access_key: ENV['AWS_SECRET_ACCESS_KEY_FOR_STEMCELLS_JENKINS_ACCOUNT']
               })

    Dir.mktmpdir do |dir|
      Dir.chdir(dir) do
        stemcell_tgz = 'latest-light-micro-bosh-stemcell.tgz'
        run("s3cmd get s3://bosh-ci-pipeline/micro-bosh-stemcell/aws/latest-light-micro-bosh-stemcell-aws.tgz #{stemcell_tgz}")
        stemcell_properties = stemcell_manifest(stemcell_tgz)
        stemcell_S3_name = "#{stemcell_properties['name']}-#{stemcell_properties['cloud_properties']['infrastructure']}"

        s3 = AWS::S3.new
        s3.buckets.create(bucket_name) # doesn't fail if already exists in your account
        bucket = s3.buckets[bucket_name]

        ami_id = stemcell_properties['cloud_properties']['ami']['us-east-1']

        obj = bucket.objects["last_successful_#{stemcell_S3_name}_ami_us-east-1"]

        obj.write(ami_id)
        obj.acl = :public_read

        puts "AMI name written to: #{obj.public_url :secure => false}"
      end
    end
  end
end
