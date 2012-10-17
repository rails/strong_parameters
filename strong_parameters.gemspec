$:.push File.expand_path("../lib", __FILE__)

# Maintain your gem's version:
require "strong_parameters/version"

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = "strong_parameters"
  s.version     = StrongParameters::VERSION
  s.authors     = ["David Heinemeier Hansson"]
  s.email       = ["david@heinemeierhansson.com"]
  s.summary     = "Permitted and required parameters for Action Pack"

  s.files = Dir["{app,config,db,lib}/**/*"] + ["MIT-LICENSE", "Rakefile", "README.rdoc"]
  s.test_files = Dir["test/**/*"]

  s.add_dependency "actionpack", ">= 3.1", "< 4.0"
  s.add_dependency "activemodel", ">= 3.1", "< 4.0"
  s.add_dependency "railties", ">= 3.1", "< 4.0"

  s.add_development_dependency "rake"
end
