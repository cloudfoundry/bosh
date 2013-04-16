module Bosh
  module Aws
    class S3
      def initialize(credentials)
        @credentials = credentials
      end

      def create_bucket(bucket_name)
        aws_s3.buckets.create(bucket_name)
      end

      def delete_bucket(bucket_name)
        bucket = fetch_bucket(bucket_name)

        bucket.clear!
        bucket.delete
      rescue AWS::S3::Errors::NoSuchBucket
      end

      def empty
        aws_s3.buckets.each do |bucket|
          begin
            bucket.delete!
          rescue AWS::S3::Errors::NoSuchBucket
            # when the bucket goes away while going through the list
          end
        end
      end

      def bucket_names
        aws_s3.buckets.map &:name
      end

      def bucket_exists?(bucket_name)
        bucket = fetch_bucket(bucket_name)
        bucket.exists?
      end

      def upload_to_bucket(bucket_name, object_name, io)
        bucket = fetch_bucket(bucket_name)
        bucket.objects[object_name].write(io)
      end

      def objects_in_bucket(bucket_name)
        fetch_bucket(bucket_name).objects.map { |object| object.key }
      end

      def fetch_object_contents(bucket_name, object_name)
        bucket = fetch_bucket(bucket_name)
        Bosh::Common.retryable(on: AWS::S3::Errors::NoSuchBucket, tries: 10) do
          bucket.objects[object_name].read
        end
      rescue AWS::S3::Errors::NoSuchKey
        nil
      end

      private

      def fetch_bucket(bucket_name)
        aws_s3.buckets[bucket_name]
      end

      def aws_s3
        @aws_s3 ||= ::AWS::S3.new(@credentials)
      end
    end
  end
end
