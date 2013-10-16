# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'nerve/version'

Gem::Specification.new do |gem|
  gem.name          = 'nerve'
  gem.version       = Nerve::VERSION
  gem.authors       = ['Martin Rhoads']
  gem.email         = ['martin.rhoads@airbnb.com']
  gem.description   = %q{description}
  gem.summary       = %q{summary}
  gem.homepage      = ''

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = %w(lib)
  gem.add_dependency 'slyphon-log4j'
  gem.add_dependency 'slyphon-zookeeper_jar'
  gem.add_dependency 'eventmachine'
  gem.add_dependency 'zk'
end
