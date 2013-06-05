= BOSH Director

== To run an instance locally:

    $ bundle install
    $ bundle exec bin/migrate -c config/bosh-director.yml

You'll now have a `director.db` file in `$ROOT/bosh/director`. Edit `config/bosh-director.yml` and change the value of `database:` to be the path to your director.db.

Next:

    $ bundle exec bin/director -c config/bosh-director.yml

You should see the director start on http://127.0.0.1:8080. Browse to that location and you'll see the Swagger UI API docs.

== To regenerate the API docs:

    $ bundle exec source2swagger -f lib/director.rb -c "##~" -o lib/public/api

TODO: rake task for API regeneration

