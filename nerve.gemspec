# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nerve/version'

Gem::Specification.new do |gem|
  gem.name          = "nerve"
  gem.version       = Nerve::VERSION
  gem.authors       = ["Martin Rhoads", "Igor Serebryany", "Pierre Carrier"]
  gem.email         = ["martin.rhoads@airbnb.com", "igor.serebryany@airbnb.com"]
  gem.description   = %q{description}
  gem.summary       = %q{summary}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]

  gem.add_runtime_dependency "json"
  gem.add_runtime_dependency "zk", "~> 1.9.2"
  gem.add_runtime_dependency "bunny", "= 1.1.0"
  gem.add_runtime_dependency "etcd", "~> 0.2.3"

  gem.add_development_dependency "rake"
  gem.add_development_dependency "rspec", "~> 3.1.0"
  gem.add_development_dependency "factory_girl"
  gem.add_development_dependency "pry"
end
