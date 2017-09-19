module Bosh::Director
  module Api::Controllers
    class JobsController < BaseController
      get '/', scope: :read do
        content_type(:json)

        if params.empty?
          templates = Models::Template.all

        elsif params['name'] && params['release_name'] && params['fingerprint']
          release = Models::Release.find(name: params['release_name'])

          unless release
            status(404)
            return
          end

          template = Models::Template.find(
            name: params['name'],
            release_id: release.id,
            fingerprint: params['fingerprint'],
          )

          unless template
            status(404)
            return
          end

          templates = [template]
        else
          status(400)
          return
        end

        result = []

        templates.each do |template|
          result << {
            name: template.name,
            fingerprint: template.fingerprint,
            spec: template.spec,
          }
        end

        JSON.generate(result)
      end
    end
  end
end
