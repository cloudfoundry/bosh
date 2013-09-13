module Bosh::Cli
  class JobCommandArgs < Struct.new(:job, :index, :args)
    def initialize(args)
      job = args.shift
      err('Please provide job name') if job.nil?
      job, index = job.split('/', 2)

      if index
        if index =~ /^\d+$/
          index = index.to_i
        else
          err('Invalid job index, integer number expected')
        end
      elsif args[0] =~ /^\d+$/
        index = args.shift.to_i
      end

      self.job = job
      self.index = index
      self.args = args
    end
  end
end
