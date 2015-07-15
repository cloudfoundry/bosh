module Bosh
  module AwsCliPlugin
    class S3
      def initialize(credentials)
        @aws_provider = AwsProvider.new(credentials)
      end

      def create_bucket(bucket_name)
        aws_s3.buckets.create(bucket_name)
      end

      def move_bucket(old_bucket, new_bucket)
        fetch_bucket(old_bucket).objects.each do |object|
          object.move_to(object.key, :bucket_name => new_bucket)
        end
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
        bucket_names.include?(bucket_name)
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

      def copy_remote_file(bucket_name, remote_file, file_name)
        say("Fetching remote file #{remote_file} from #{bucket_name} bucket")
        bucket = aws_s3.buckets[bucket_name]
        object = bucket.objects[remote_file]
        release_file = Tempfile.new file_name
        Bosh::Cli::FileWithProgressBar.open(release_file, 'wb') do |f|
          f.size=object.content_length
          object.read do |chunk|
            f.write chunk
          end
        end
        release_file
      rescue AWS::S3::Errors::NoSuchKey => e
        new_exception = Exception.new("Can't find #{remote_file} in bucket #{bucket_name}")
        new_exception.set_backtrace(e.backtrace)
        raise new_exception
      end

      private

      attr_reader :aws_provider

      def fetch_bucket(bucket_name)
        aws_s3.buckets[bucket_name]
      end

      def aws_s3
        aws_provider.s3
      end
    end
  end
end
