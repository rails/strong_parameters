source 'http://rubygems.org'
gemspec :path => "./../.."

gem "actionpack", "~> 3.2.0"
gem "railties", "~> 3.2.0"
gem "activemodel", "~> 3.2.0"

if RUBY_VERSION < '1.9.3'
  gem 'rake', '~> 10.0'
  gem 'i18n', '~> 0.6.11'
  gem 'rack-cache', '< 1.3'
else
  gem 'rake'
end
