require 'json'
require 'nerve/reporter'
require 'nerve/reporter/base'
require 'nerve/service_watcher'

class Nerve::Reporter::Base
  attr_reader :data
end

describe "example services are valid" do
  Dir.foreach("#{File.dirname(__FILE__)}/../example/nerve_services") do |item|
    next if item == '.' or item == '..'
    service_data = JSON.parse(IO.read("#{File.dirname(__FILE__)}/../example/nerve_services/#{item}"))
    service_data['name'] = item.gsub(/\.json$/, '')
    service_data['instance_id'] = '1'

    context "when #{item} can be initialized as a valid reporter" do
      it 'creates a valid reporter in new_from_service' do
        reporter = nil
        expect { reporter = Nerve::Reporter.new_from_service(service_data) }.to_not raise_error()
        expect(reporter.is_a?(Nerve::Reporter::Base)).to eql(true)
      end
      it 'saves the weight data' do
        expect(JSON.parse(Nerve::Reporter.new_from_service(service_data).data)['weight']).to eql(2)
      end
    end

    context "when #{item} can be initialized as a valid service watcher" do
      it "creates a valid service watcher for #{item}" do
        watcher = nil
        expect { watcher = Nerve::ServiceWatcher.new(service_data) }.to_not raise_error()
        expect(watcher.is_a?(Nerve::ServiceWatcher)).to eql(true)
      end
    end
  end
end

