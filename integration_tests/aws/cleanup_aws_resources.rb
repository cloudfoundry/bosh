VPC_OUTFILE=`ls integration_tests/aws/create-vpc-output-*.yml`.strip
puts "Using VPC output: #{VPC_OUTFILE}"
puts File.read(VPC_OUTFILE)
raise 'Could not perform cleanup' unless system("bundle", "exec", "bosh", "aws", "delete", "vpc", VPC_OUTFILE)
puts "CLEANUP SUCCESSFUL"