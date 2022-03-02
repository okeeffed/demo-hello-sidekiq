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
