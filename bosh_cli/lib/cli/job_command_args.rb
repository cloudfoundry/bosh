module Bosh::Cli
  class JobCommandArgs < Struct.new(:job, :id, :args)
    def initialize(args)
      job = args.shift
      err('Please provide job name') if job.nil?
      job, id = job.split('/', 2)

      id = args.shift if id.nil?

      self.job = job
      self.id = id
      self.args = args
    end

    def index
      id
    end
  end
end
