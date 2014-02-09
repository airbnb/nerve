require 'json'
require 'nerve/reporter'
require 'nerve/service_watcher'

describe "example services are valid" do
  Dir.foreach("#{File.dirname(__FILE__)}/../example/nerve_services") do |item|
    next if item == '.' or item == '..'
    service_data = JSON.parse(IO.read("#{File.dirname(__FILE__)}/../example/nerve_services/#{item}"))
    service_data['name'] = item.gsub(/\.json$/, '')
    service_data['instance_id'] = '1'
    context "when #{item} can be initialized as a valid reporter" do
      reporter = nil
      it 'Can new_from_service' do
        expect { reporter = Nerve::Reporter.new_from_service(service_data) }.to_not raise_error()
      end
      it 'Created a reporter object' do
        expect(reporter.is_a?(Nerve::Reporter::Base)).to eql(true)
      end
    end
    context "when #{item} can be initialized as a valid service watcher" do
      it do
        watcher = nil
        expect { watcher = Nerve::ServiceWatcher.new(service_data) }.to_not raise_error()
        expect(watcher.is_a?(Nerve::ServiceWatcher)).to eql(true)
      end
    end
  end
end

