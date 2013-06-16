# BOSH Director

## To run an instance locally:

    $ bundle install
    $ bundle exec bin/migrate -c config/bosh-director.yml
    $ bundle exec bin/director -c config/bosh-director.yml

You should see the director start on [http://admin:admin@127.0.0.1:8080](http://admin:admin@127.0.0.1:8080). Browse to that location and you'll see the Swagger UI API docs.

## To regenerate the API docs:

    $ bundle exec source2swagger -f lib/director.rb -c "##~" -o lib/public/api

TODO: rake task for API regeneration

