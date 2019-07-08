require 'spec_helper'
require 'nerve/configuration_manager'
require 'nerve/service_watcher'
require 'nerve/reporter'
require 'nerve/reporter/base'
require 'nerve'

def make_mock_service_watcher
    mock_service_watcher = instance_double(Nerve::ServiceWatcher)
    allow(mock_service_watcher).to receive(:start)
    allow(mock_service_watcher).to receive(:stop)
    allow(mock_service_watcher).to receive(:alive?).and_return(true)
    allow(mock_service_watcher).to receive(:was_up).and_return(true)
    mock_service_watcher
end

describe Nerve::Nerve do
  let(:config_manager) { Nerve::ConfigurationManager.new() }
  let(:mock_config_manager) { instance_double(Nerve::ConfigurationManager) }
  let(:nerve_config) { "#{File.dirname(__FILE__)}/../../example/nerve.conf.json" }
  let(:nerve_instance_id) { 'testid' }
  let(:mock_service_watcher_one) { make_mock_service_watcher() }
  let(:mock_service_watcher_two) { make_mock_service_watcher() }
  let(:mock_reporter) { Nerve::Reporter::Base.new({}) }

  describe 'check run' do
    subject {
      expect(config_manager).to receive(:parse_options_from_argv!).and_return({
        :config => nerve_config,
        :instance_id => nerve_instance_id,
        :check_config => true
      })
      config_manager.parse_options!
      Nerve::Nerve.new(config_manager)
    }

    it 'starts up and checks config' do
      expect{subject.run}.not_to raise_error
    end
  end

  describe 'full application run' do
    before(:each) {
      $EXIT = false

      allow(Nerve::Reporter).to receive(:new_from_service) {
        mock_reporter
      }
      allow(Nerve::ServiceWatcher).to receive(:new) { |config|
        if config['name'] == 'service1'
          mock_service_watcher_one
        else
          mock_service_watcher_two
        end
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

    it 'does a regular run and finishes' do
      nerve = Nerve::Nerve.new(mock_config_manager)

      expect(nerve).to receive(:heartbeat) {
        $EXIT = true
      }

      expect{ nerve.run }.not_to raise_error
    end

    it 'relaunches dead watchers' do
      nerve = Nerve::Nerve.new(mock_config_manager)

      iterations = 2

      # One service will fail an alive? call and need to be respawned
      expect(nerve).to receive(:launch_watcher).twice.with('service1', anything).and_call_original
      expect(nerve).to receive(:reap_watcher).twice.with('service1').and_call_original
      expect(nerve).to receive(:launch_watcher).once.with('service2', anything).and_call_original
      expect(nerve).to receive(:reap_watcher).once.with('service2').and_call_original

      expect(nerve).to receive(:heartbeat).exactly(iterations + 1).times do
        if iterations == 2
          expect(mock_service_watcher_one).to receive(:alive?).and_return(false)
          nerve.instance_variable_set(:@config_to_load, true)
        elsif iterations == 1
          expect(mock_service_watcher_one).to receive(:alive?).and_return(true)
          nerve.instance_variable_set(:@config_to_load, true)
        else
          $EXIT = true
        end
        iterations -= 1
      end

      expect{ nerve.run }.not_to raise_error
    end

    it 'responds to changes in configuration' do
      nerve = Nerve::Nerve.new(mock_config_manager)

      iterations = 5
      expect(nerve).to receive(:heartbeat).exactly(iterations + 1).times do
        if iterations == 5
          expect(nerve.instance_variable_get(:@watchers).keys).to contain_exactly('service1', 'service2')

          # Remove service2 from the config
          expect(mock_config_manager).to receive(:config).and_return({
            'instance_id' => nerve_instance_id,
            'services' => {
              'service1' => {
                'host' => 'localhost',
                'port' => 1234,
                'load_test_concurrency' => 2
              },
            }
          })
          nerve.instance_variable_set(:@config_to_load, true)
        elsif iterations == 4
          expect(nerve.instance_variable_get(:@watchers).keys).to contain_exactly('service1_0', 'service1_1')
          expect(nerve.instance_variable_get(:@watchers_desired).keys).to contain_exactly('service1_0', 'service1_1')
          expect(nerve.instance_variable_get(:@config_to_load)).to eq(false)

          # Change the configuration of service1
          expect(mock_config_manager).to receive(:config).and_return({
            'instance_id' => nerve_instance_id,
            'services' => {
              'service1' => {
                'host' => 'localhost',
                'port' => 1234
              },
            }
          })
          nerve.instance_variable_set(:@config_to_load, true)

        elsif iterations == 3
          expect(nerve.instance_variable_get(:@watchers).keys).to contain_exactly('service1')
          expect(nerve.instance_variable_get(:@watchers_desired).keys).to contain_exactly('service1')
          expect(nerve.instance_variable_get(:@config_to_load)).to eq(false)

          # Change the configuration of service1
          expect(mock_config_manager).to receive(:config).and_return({
            'instance_id' => nerve_instance_id,
            'services' => {
              'service1' => {
                'host' => 'localhost',
                'port' => 1236
              },
            }
          })
          nerve.instance_variable_set(:@config_to_load, true)
        elsif iterations == 2
          expect(nerve.instance_variable_get(:@watchers).keys).to contain_exactly('service1')
          expect(nerve.instance_variable_get(:@watchers_desired).keys).to contain_exactly('service1')
          expect(nerve.instance_variable_get(:@watchers_desired)['service1']['port']).to eq(1236)
          expect(nerve.instance_variable_get(:@config_to_load)).to eq(false)

          # Add another service
          expect(mock_config_manager).to receive(:config) { {
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

          nerve.instance_variable_set(:@config_to_load, true)
        elsif iterations == 1
          expect(nerve.instance_variable_get(:@watchers).keys).to contain_exactly('service1', 'service4')
          nerve.instance_variable_set(:@config_to_load, true)
        else
          $EXIT = true
        end
        iterations -= 1
      end

      expect{ nerve.run }.not_to raise_error
    end

  end
end

