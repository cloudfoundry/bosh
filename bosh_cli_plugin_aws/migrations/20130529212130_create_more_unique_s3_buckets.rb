class CreateMoreUniqueS3Buckets < Bosh::Aws::Migration

  def s3_safe_full_domain_name
    config['vpc']['domain'].gsub(".","-")
  end

  def buckets
    {
     "#{s3_safe_full_domain_name}-bosh-blobstore" => "#{config['name']}-bosh-blobstore",
     "#{s3_safe_full_domain_name}-bosh-artifacts" => "#{config['name']}-bosh-artifacts"
    }
  end

  def execute

    buckets.each_key do |bucket|
      say "creating bucket #{bucket}"
      s3.create_bucket(bucket)
    end

    buckets.each_pair do |new_bucket, old_bucket|
      next unless s3.bucket_exists?(old_bucket)
      say "copying contents of #{old_bucket} to #{new_bucket}"
      s3.copy_bucket(old_bucket, new_bucket)
      say "deleting bucket #{old_bucket}"
      s3.delete_bucket(old_bucket)
    end

  end
end
