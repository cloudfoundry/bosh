require "fileutils"
system "rm -f integration_tests/aws/create-vpc-output*.yml"
raise "AWS failed to create resources" unless system "bundle exec bosh aws create vpc integration_tests/aws/aws_configuration_template.yml.erb"
puts "AWS RESOURCES CREATED SUCCESSFULLY!"
