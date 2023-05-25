# coding: utf-8
require File.expand_path('../lib/bosh/registry/version', __FILE__)

Gem::Specification.new do |spec|
  spec.name         = 'bosh-registry'
  spec.version      = Bosh::Registry::VERSION
  spec.platform     = Gem::Platform::RUBY
  spec.summary      = 'BOSH Registry'
  spec.description  = 'BOSH Registry'
  spec.author       = 'VMware'
  spec.homepage     = 'https://github.com/cloudfoundry/bosh'
  spec.license      = 'Apache 2.0'
  spec.email        = 'support@cloudfoundry.com'
  spec.required_ruby_version = Gem::Requirement.new('>= 1.9.3')

  spec.files        = Dir['README.md', 'db/**/*', 'lib/**/*'].select{ |f| File.file? f }
  spec.require_path = 'lib'
  spec.bindir       = 'bin'
  spec.executables  = %w(bosh-registry bosh-registry-migrate)

  spec.add_dependency 'sequel',    '~>5.29.0'
  spec.add_dependency 'sinatra',   '~>2.0.2'
  spec.add_dependency 'thin'
  spec.add_dependency 'fog-openstack', '~>0.1.31'
  spec.add_dependency 'aws-sdk'
  spec.add_dependency 'fog-core',   '~>1.45.0'
  spec.add_dependency 'builder',    '~>3.1.4'
  spec.add_dependency 'excon'
end
