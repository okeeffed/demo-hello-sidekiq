# README

## Steps to do

```s
# Create project (using Rails 7.0.2.2)
$ rails new demo-hello-sidekiq
$ cd demo-hello-sidekiq
$ touch Procfile.dev config/initializers/sidekiq.rb bin/dev
# Add permissions to run bin/dev
$ chmod u+x bin/dev

# Add required gems
$ bundler add sidekiq

# Generate a controller route for our demo
$ bin/rails g controller jobs create
      create  app/controllers/jobs_controller.rb
       route  get 'jobs/create'
      invoke  erb
      create    app/views/jobs
      create    app/views/jobs/create.html.erb
      invoke  test_unit
      create    test/controllers/jobs_controller_test.rb
      invoke  helper
      create    app/helpers/jobs_helper.rb
      invoke    test_unit

# Generate a basic job
$ bin/rails g sidekiq:job hello
      create  app/sidekiq/hello_job.rb
      create  test/sidekiq/hello_job_test.rb
```

First update the routes:

```rb
Rails.application.routes.draw do
  resources :jobs, only: [:create]
end
```

Update what is in `app/sidekiq/hello_job.rb`:

```rb
class HelloJob
  include Sidekiq::Job

  def perform(*_args)
    # Do something
    p "HelloJob started with args #{_args}"

    # Sleep to simulate a time-consuming task
    sleep 5

    # Will display current time, milliseconds included
    p "HelloJob #{Time.now.strftime('%F - %H:%M:%S.%L')}"
  end
end
```

Update our `config/application.rb`:

```rb
require_relative "boot"

require "rails/all"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module DemoHelloSidekiq
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 7.0

		# Enable us to send requests without auth token
		config.action_controller.default_protect_from_forgery = false if ENV['RAILS_ENV'] == 'development'
  end
end
```

Inside of `config/initializers/sidekiq.rb`:

```rb
# inside config/initializers/sidekiq.rb

Sidekiq.configure_server do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1') }
end
Sidekiq.configure_client do |config|
  config.redis = { url: ENV.fetch('REDIS_URL', 'redis://localhost:6379/1') }
end
```

Inside of `Procfile.dev`:

```s
web: bin/rails s
worker: bundle exec sidekiq
```

Inside of `bin/dev`:

```sh
#!/usr/bin/env bash

if ! gem list --silent --installed foreman
then
  echo "Installing foreman..."
  gem install foreman
fi

foreman start -f Procfile.dev "$@"
```

Finally, let's update our `app/controllers/jobs_controller.rb`:

```rb
class JobsController < ApplicationController
  def create
    HelloJob.perform_async('job', 5)
    render json: { message: 'Accepted' }, status: :accepted
  end
end
```

## Testing our job

Now we can start the server with `bin/dev`.

```s
$ bin/dev
10:36:56 web.1    | started with pid 77188
10:36:56 worker.1 | started with pid 77189
10:36:58 web.1    | => Booting Puma
10:36:58 web.1    | => Rails 7.0.2.2 application starting in development
10:36:58 web.1    | => Run `bin/rails server --help` for more startup options
10:36:58 worker.1 | 2022-03-02T00:36:58.612Z pid=77189 tid=1r01 INFO: Booting Sidekiq 6.4.1 with redis options {:url=>"redis://localhost:6379/1"}
10:36:58 worker.1 | 2022-03-02T00:36:58.913Z pid=77189 tid=1r01 INFO: Booted Rails 7.0.2.2 application in development environment
10:36:58 worker.1 | 2022-03-02T00:36:58.913Z pid=77189 tid=1r01 INFO: Running in ruby 2.7.3p183 (2021-04-05 revision 6847ee089d) [x86_64-darwin20]
10:36:58 worker.1 | 2022-03-02T00:36:58.913Z pid=77189 tid=1r01 INFO: See LICENSE and the LGPL-3.0 for licensing details.
10:36:58 worker.1 | 2022-03-02T00:36:58.913Z pid=77189 tid=1r01 INFO: Upgrade to Sidekiq Pro for more features and support: https://sidekiq.org
10:36:59 web.1    | Puma starting in single mode...
10:36:59 web.1    | * Puma version: 5.6.2 (ruby 2.7.3-p183) ("Birdie's Version")
10:36:59 web.1    | *  Min threads: 5
10:36:59 web.1    | *  Max threads: 5
10:36:59 web.1    | *  Environment: development
10:36:59 web.1    | *          PID: 77188
10:36:59 web.1    | * Listening on http://127.0.0.1:5000
10:36:59 web.1    | * Listening on http://[::1]:5000
10:36:59 web.1    | Use Ctrl-C to stop
```

To start a job, we can make a POST call to `http://localhost:5000/jobs`:

```s
$ http POST http://localhost:5000/jobs
HTTP/1.1 202 Accepted
Cache-Control: no-cache
Content-Type: application/json; charset=utf-8
Referrer-Policy: strict-origin-when-cross-origin
Server-Timing: start_processing.action_controller;dur=0.108642578125, process_action.action_controller;dur=2.332763671875
Transfer-Encoding: chunked
Vary: Accept
X-Content-Type-Options: nosniff
X-Download-Options: noopen
X-Frame-Options: SAMEORIGIN
X-Permitted-Cross-Domain-Policies: none
X-Request-Id: 4b7ed09f-f449-42a6-abcd-6a2c8fb3487a
X-Runtime: 0.062683
X-XSS-Protection: 0

{
    "message": "Accepted"
}
```

Our logs will show us that the web processes the controller, then the job is handled by the working (with job completion occurring 5 seconds later).

```s
10:42:57 web.1    | Started POST "/jobs" for ::1 at 2022-03-02 10:42:57 +1000
10:42:57 web.1    | Processing by JobsController#create as */*
10:42:57 worker.1 | 2022-03-02T00:42:57.674Z pid=79840 tid=2264 class=HelloJob jid=2d01fd26fa36e584afe284a3 INFO: start
10:42:57 web.1    | Completed 202 Accepted in 2ms (Views: 0.3ms | Allocations: 425)
10:42:57 web.1    |
10:42:57 web.1    |
10:42:57 worker.1 | "HelloJob started with args [\"job\", 5]"
10:43:02 worker.1 | "HelloJob 2022-03-02 - 10:43:02.752"
10:43:02 worker.1 | 2022-03-02T00:43:02.752Z pid=79840 tid=2264 class=HelloJob jid=2d01fd26fa36e584afe284a3 elapsed=5.078 INFO: done
```

Hooray!

We also have the capability of using the `perform_in` and `perform_at` API methods to schedule jobs.

Update the controller to see this in action:

```rb
class JobsController < ApplicationController
  def create
    HelloJob.perform_async('perform_async job')
    HelloJob.perform_in(10.seconds, 'perform_in job')
    HelloJob.perform_at(20.seconds.from_now, 'perform_at job')
    render json: { message: 'Accepted' }, status: :accepted
  end
end
```

Again, send a POST request to our `/jobs` routes results in the following:

```s
10:51:38 web.1    | Started POST "/jobs" for ::1 at 2022-03-02 10:51:38 +1000
10:51:38 web.1    | Processing by JobsController#create as */*
10:51:38 worker.1 | 2022-03-02T00:51:38.630Z pid=79840 tid=2214 class=HelloJob jid=e38a834662f55fec2fc0c0a8 INFO: start
10:51:38 web.1    | Completed 202 Accepted in 46ms (Views: 0.3ms | Allocations: 622)
10:51:38 web.1    |
10:51:38 web.1    |
10:51:38 worker.1 | "HelloJob started with args [\"perform_async job\"]"
10:51:43 worker.1 | "HelloJob 2022-03-02 - 10:51:43.710"
10:51:43 worker.1 | 2022-03-02T00:51:43.710Z pid=79840 tid=2214 class=HelloJob jid=e38a834662f55fec2fc0c0a8 elapsed=5.08 INFO: done
10:51:55 worker.1 | 2022-03-02T00:51:55.054Z pid=79840 tid=2214 class=HelloJob jid=56a274fa9a9db51df8591674 INFO: start
10:51:55 worker.1 | "HelloJob started with args [\"perform_in job\"]"
10:52:00 worker.1 | "HelloJob 2022-03-02 - 10:52:00.067"
10:52:00 worker.1 | 2022-03-02T00:52:00.067Z pid=79840 tid=2214 class=HelloJob jid=56a274fa9a9db51df8591674 elapsed=5.013 INFO: done
10:52:02 worker.1 | 2022-03-02T00:52:02.205Z pid=79840 tid=221o class=HelloJob jid=2672ef81124e468da977f789 INFO: start
10:52:02 worker.1 | "HelloJob started with args [\"perform_at job\"]"
10:52:07 worker.1 | "HelloJob 2022-03-02 - 10:52:07.217"
10:52:07 worker.1 | 2022-03-02T00:52:07.217Z pid=79840 tid=221o class=HelloJob jid=2672ef81124e468da977f789 elapsed=5.012 INFO: done
```
