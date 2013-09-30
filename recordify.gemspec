# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'recordify/version'

s = Gem::Specification.new

s.name          = "recordify"
s.version       = Recordify::VERSION
s.authors       = ["Ruben Jenster"]
s.email         = ["rjenster@gmail.com"]
s.description   = %q{Record your spotify playlists}
s.summary       = %q{Record your spotify playlists}
s.homepage      = "http://github.com/r10r/recordify"

s.files         = `git ls-files`.split($/)
s.executables   = s.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
s.test_files    = s.files.grep(%r{^(test|spec|features)/})
s.require_paths = ["lib"]

s.add_development_dependency "rake"
s.add_development_dependency "simplecov"
s.add_development_dependency "simplecov-rcov"

s.add_dependency 'spotify'
s.add_dependency 'pry'
s.add_dependency 'taglib-ruby'  # brew install taglib
s.add_dependency 'mkfifo'
s

