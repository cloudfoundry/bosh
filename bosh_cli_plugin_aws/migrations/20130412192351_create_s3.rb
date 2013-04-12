class CreateS3 < Bosh::Aws::Migration
  def execute
    if !config["s3"]
      say "s3 not set in config.  Skipping"
      return
    end

    config["s3"].each do |e|
      bucket_name = e["bucket_name"]
      say "creating bucket #{bucket_name}"
      s3.create_bucket(bucket_name)
    end
  end
end
