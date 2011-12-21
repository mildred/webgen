#!/usr/bin/env ruby

require 'rake'

PKG_FILES = FileList.new([
                          'Rakefile',
                          'setup.rb',
                          'VERSION',
                          'ChangeLog',
                          'AUTHORS',
                          'THANKS',
                          'COPYING',
                          'GPL',
                          'bin/webgen',
                          'data/**/*',
                          'doc/**/*',
                          'lib/**/*.rb',
                          'man/man1/webgen.1',
                          'misc/**/*',
                          'test/test_*.rb',
                          'test/helper.rb',
                         ]) do |fl|
  fl.exclude('data/**/.gitignore')
end
