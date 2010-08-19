module Bosh::Director

  class DirectorError < StandardError; end
  class UserNotFound < DirectorError; end
  class ReleaseBundleInvalid < DirectorError; end
  class TaskInvalid < DirectorError; end
  class PackageInvalid < DirectorError; end
  class JobInvalid < DirectorError; end
  class DeploymentInvalid < DirectorError; end
  
  class UserInvalid < DirectorError

    attr_reader :errors

    def initialize(errors)
      @errors = errors
    end

    def to_s
      @errors.pretty_inspect
    end
  end

end