class CreateMoreUniqueS3Buckets < Bosh::AwsCliPlugin::Migration
  def s3_safe_full_domain_name
    config['vpc']['domain'].gsub(".","-")
  end

  def old_prefix
    config['name']
  end

  def buckets
    {
     "#{s3_safe_full_domain_name}-bosh-blobstore" => "#{old_prefix}-bosh-blobstore",
     "#{s3_safe_full_domain_name}-bosh-artifacts" => "#{old_prefix}-bosh-artifacts"
    }
  end

  def execute
    return if s3_safe_full_domain_name == old_prefix

    buckets.each_key do |bucket|
      say "creating bucket #{bucket}"
      next if s3.bucket_exists?(bucket)
      s3.create_bucket(bucket)
    end

    buckets.each_pair do |new_bucket, old_bucket|
      next unless s3.bucket_exists?(old_bucket)
      say "moving contents of #{old_bucket} to #{new_bucket}"
      s3.move_bucket(old_bucket, new_bucket)
      say "deleting bucket #{old_bucket}"
      s3.delete_bucket(old_bucket)
    end
  end
end
