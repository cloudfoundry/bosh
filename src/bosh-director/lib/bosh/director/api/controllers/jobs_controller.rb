module Bosh::Director
  module Api::Controllers
    class JobsController < BaseController
      get '/', scope: :read do
        content_type(:json)

        unless params['name'] && params['release_name'] && params['fingerprint']
          status(400)
          return
        end

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

        JSON.generate([{
          name: template.name,
          fingerprint: template.fingerprint,
          spec: template.spec,
        }])
      end
    end
  end
end
