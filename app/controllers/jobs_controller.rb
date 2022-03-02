class JobsController < ApplicationController
  def create
    HelloJob.perform_async('perform_async job')
    HelloJob.perform_in(10.seconds, 'perform_in job')
    HelloJob.perform_at(20.seconds.from_now, 'perform_at job')
    render json: { message: 'Accepted' }, status: :accepted
  end
end
