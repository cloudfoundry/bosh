require 'rake'

module Bosh::Dev
  class PromotableArtifact
    def initialize(command)
      @command = command
    end

    def promote
      Rake::FileUtilsExt.sh(@command)
    end
  end
end
