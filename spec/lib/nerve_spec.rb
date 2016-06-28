require 'spec_helper'
require 'nerve/configuration_manager'
require 'nerve/service_watcher'
require 'nerve/reporter'
require 'nerve'

describe Nerve::Nerve do
  let(:config_manager) { Nerve::ConfigurationManager.new() }
  let(:mock_config_manager) { double() }
  let(:mock_method) { double() }
  let(:nerve_config) { "#{File.dirname(__FILE__)}/../../example/nerve.conf.json" }
  let(:nerve_instance_id) { 'testid' }

  describe 'check run' do
    subject {
      allow(config_manager).to receive(:parse_options_from_argv!) { {
        :config => nerve_config,
        :instance_id => nerve_instance_id,
        :check_config => true
      } }
      config_manager.parse_options!
      Nerve::Nerve.new(config_manager)
    }

    it 'starts up and checks config' do
      expect{subject.run}.not_to raise_error
    end
  end

  describe 'responds to reconfigures' do
    before(:each) {
      allow_any_instance_of(Nerve::ServiceWatcher).to receive(:run) {
        # ServiceWatchers just infinite loop
        loop do
          sleep 0.5
          break if Thread.current[:finish]
        end
      }
      allow(Nerve::Reporter).to receive(:new_from_service) { |service|
        mock_method
      }
      allow(mock_config_manager).to receive(:reload!) { }
      allow(mock_config_manager).to receive(:config) { {
        'instance_id' => nerve_instance_id,
        'services' => {
          'service1' => {
            'host' => 'localhost',
            'port' => 1234
          },
          'service2' => {
            'host' => 'localhost',
            'port' => 1235
          },
        }
      } }
      allow(mock_config_manager).to receive(:options) { {
        :config => 'noop',
        :instance_id => nerve_instance_id,
        :check_config => false
      } }
    }

    subject {
      Nerve::Nerve.new(mock_config_manager)
    }

    it 'does a regular run and finishes' do
      app = Thread.new {
        subject.run
      }
      wait_for { subject.instance_variable_get(:@watchers).keys }.to contain_exactly('service1', 'service2')
      # Terminate the app
      app.raise()
      wait_for { app.alive? }.to eq(false)
    end


    it 'responds to SIGHUPs' do
      app = Thread.new {
        subject.run
      }

      wait_for { subject.instance_variable_get(:@watchers).keys }.to contain_exactly('service1', 'service2')

      # Remove service2 from the config
      allow(mock_config_manager).to receive(:config) { {
        'instance_id' => nerve_instance_id,
        'services' => {
          'service1' => {
            'host' => 'localhost',
            'port' => 1234
          },
        }
      } }

      # Simulate a SIGHUP
      subject.instance_variable_set(:@config_to_load, true)
      wait_for { subject.instance_variable_get(:@watchers).keys }.to contain_exactly('service1')


      # Change the configuration of service1
      allow(mock_config_manager).to receive(:config) { {
        'instance_id' => nerve_instance_id,
        'services' => {
          'service1' => {
            'host' => 'localhost',
            'port' => 1236
          },
        }
      } }
      subject.instance_variable_set(:@config_to_load, true)
      wait_for { subject.instance_variable_get(:@config_to_load) }.to eq(false)
      wait_for { subject.instance_variable_get(:@watchers_desired)['service1']['port'] }.to eq(1236)

      # Add another service
      allow(mock_config_manager).to receive(:config) { {
        'instance_id' => nerve_instance_id,
        'services' => {
          'service1' => {
            'host' => 'localhost',
            'port' => 1236
          },
          'service4' => {
            'host' => 'localhost',
            'port' => 1235
          },
        }
      } }

      subject.instance_variable_set(:@config_to_load, true)
      wait_for { subject.instance_variable_get(:@watchers).keys }.to contain_exactly('service1', 'service4')

      # Terminate the app
      app.raise()

      wait_for { app.alive? }.to eq(false)
    end
  end
end

