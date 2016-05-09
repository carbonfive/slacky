# -*- encoding: utf-8 -*-
$LOAD_PATH << File.dirname(__FILE__) + "/lib"
require 'slacky/version'

Gem::Specification.new do |s|
  s.name        = "slacky"
  s.version     = Slacky::VERSION
  s.authors     = ["Michael Wynholds"]
  s.email       = ["mike@carbonfive.com"]
  s.homepage    = ""
  s.summary     = %q{Carbon Five Slack bot gem}
  s.description = %q{Carbon Five Slack bot gem}

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.add_runtime_dependency 'slack-ruby-client', ">= 0.6"
  s.add_runtime_dependency 'pg'
  s.add_runtime_dependency 'eventmachine'
  s.add_runtime_dependency 'faye-websocket'
  s.add_runtime_dependency 'em-cron'
  s.add_runtime_dependency 'tzinfo'
  s.add_runtime_dependency 'tzinfo-data'
  s.add_runtime_dependency 'dotenv'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'minitest'
  s.add_development_dependency 'factory_girl'
end
