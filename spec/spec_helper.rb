require 'support/process'
require 'support/helpers'
require 'zk'

include TimeoutHelper

RSpec.configure do |config|
  config.color_enabled = true
  HELPERS.each { |h| config.include(h) }

  config.after(:each) do
    Nerve::Process.stop_all(:signal => :KILL)
  end
end

at_exit do
  Nerve::Process.stop_all(:signal => :KILL)
end