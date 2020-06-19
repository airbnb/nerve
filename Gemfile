source 'https://rubygems.org'
gemspec

if Gem::Version.new(RUBY_VERSION.dup) < Gem::Version.new("2.3")
  # There appears to be an issue with json 2.3.* in ruby 1.9.3
  gem "json", "< 2.3"
end
