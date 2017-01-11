require 'peach'
require 'bosh/dev/download_adapter'
require 'bosh/dev/upload_adapter'
require 'bosh/dev/command_helper'
require 'bosh/stemcell/archive'
require 'bosh/stemcell/archive_filename'
require 'bosh/stemcell/stemcell'
require 'logging'

module Bosh::Dev
  class Build
    include CommandHelper

    attr_reader :number, :gem_number

    def self.candidate
      logger = Logging.logger(STDERR)
      number = ENV['CANDIDATE_BUILD_NUMBER']
      gem_number = ENV['CANDIDATE_BUILD_GEM_NUMBER'] || number

      if number
        logger.info("CANDIDATE_BUILD_NUMBER is #{number}. Using candidate build.")
        Build.new(number, gem_number, logger)
      else
        logger.info('CANDIDATE_BUILD_NUMBER not set. Using local build.')

        subnum = ENV['STEMCELL_BUILD_NUMBER']
        if subnum
          logger.info("STEMCELL_BUILD_NUMBER is #{subnum}. Using local build with stemcell build number.")
        else
          logger.info('STEMCELL_BUILD_NUMBER not set. Using local build.')
          subnum = '0000'
        end

        Build.new(subnum, subnum, logger)
      end
    end

    def self.build_number
      ENV.fetch('CANDIDATE_BUILD_NUMBER', '0000')
    end

    def initialize(number, gem_number, logger)
      @number = number
      @gem_number = gem_number
      @logger = logger
    end

    private

    attr_reader :logger
  end
end
