# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nerve/version'

Gem::Specification.new do |gem|
  gem.name          = "nerve"
  gem.version       = Nerve::VERSION
  gem.authors       = ["Martin Rhoads", "Igor Serebryany", "Pierre Carrier", "Joseph Lynch"]
  gem.email         = ["martin.rhoads@airbnb.com", "igor.serebryany@airbnb.com", "jlynch@yelp.com"]
  gem.description   = "Nerve is a service registration daemon. It performs health "\
                      "checks on your service and then publishes success or failure "\
                      "into one of several registries (currently, zookeeper or etcd). "\
                      "Nerve is half or SmartStack, and is designed to be operated "\
                      "along with Synapse to provide a full service discovery framework"
  gem.summary       = %q{A service registration daemon}
  gem.homepage      = "https://github.com/airbnb/nerve"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency "json"
  gem.add_runtime_dependency "zk", "~> 1.9.2"
  gem.add_runtime_dependency "bunny", "= 1.1.0"
  gem.add_runtime_dependency "redis", "= 3.3.5"
  gem.add_runtime_dependency "etcd", "~> 0.2.3"
  gem.add_runtime_dependency "dogstatsd-ruby", "~> 3.3.0"
  gem.add_runtime_dependency "activesupport", '~> 4.2', ">= 4.2.2"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec", "~> 3.1.0"
  gem.add_development_dependency "factory_girl"
  gem.add_development_dependency "pry"
end
