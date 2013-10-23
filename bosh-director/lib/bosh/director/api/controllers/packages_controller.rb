require 'bosh/director/api/controllers/base_controller'

module Bosh::Director
  module Api::Controllers
    class PackagesController < BaseController
      post '/packages/matches', :consumes => :yaml do
        manifest = Psych.load(request.body)
        unless manifest.is_a?(Hash) && manifest['packages'].is_a?(Array)
          raise BadManifest, "Manifest doesn't have a usable packages section"
        end

        fp_list = []
        sha1_list = []

        manifest['packages'].each do |package|
          fp_list << package['fingerprint'] if package['fingerprint']
          sha1_list << package['sha1'] if package['sha1']
        end

        filter = {:fingerprint => fp_list, :sha1 => sha1_list}.sql_or

        result = Models::Package.where(filter).all.map { |package|
          [package.sha1, package.fingerprint]
        }.flatten.compact.uniq

        json_encode(result)
      end
    end
  end
end
