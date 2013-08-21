require 'support/process'
require 'support/process/nerve'
require 'support/process/zookeeper'

RSpec.configure do |config|
  config.color_enabled = true

  config.after(:each) do
    Nerve::Test::Process.stop_all
  end
end

at_exit do
  Nerve::Test::Process.stop_all
end