module Bosh
  module Aws
    class S3
      def initialize(credentials)
        @credentials = credentials
      end

      def create_bucket(bucket_name)
        aws_s3.buckets.create(bucket_name)
      end

      def empty
        aws_s3.buckets.each &:delete!
      end

      def bucket_names
        aws_s3.buckets.map &:name
      end

      private

      def aws_s3
        @aws_s3 ||= ::AWS::S3.new(@credentials)
      end
    end
  end
end
