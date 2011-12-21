# -*- ruby -*-

require File.expand_path(File.join(File.dirname(__FILE__), "common.rb"))

$:.unshift('lib')
require 'webgen/version'

unless $gemspec_from_rake
  Dir.chdir(File.dirname(__FILE__)) do
    system "rake VERSION ChangeLog"
  end
end

$spec = Gem::Specification.new do |s|

  #### Basic information
  s.name = 'webgen'
  s.version = Webgen::VERSION
  s.summary = 'webgen is a fast, powerful, and extensible static website generator.'
  s.description = <<EOF
webgen is used to generate static websites from templates and content
files (which can be written in a markup language). It can generate
dynamic content like menus on the fly and comes with many powerful
extensions.
EOF
  s.post_install_message = <<EOF

Thanks for choosing webgen! Here are some places to get you started:
* The webgen User Documentation at <http://webgen.rubyforge.org/documentation/index.html>
* The mailing list archive at <http://rubyforge.org/pipermail/webgen-users/>

Have a look at <http://webgen.rubyforge.org/news/index.html> for a list of changes!

Have fun!

EOF

  #### Dependencies, requirements and files

  s.files = PKG_FILES.to_a
  s.add_dependency('cmdparse', '>= 2.0.2')
  s.add_dependency('kramdown', '= 0.10.0')
  s.add_development_dependency('maruku', '>= 0.6.0')
  s.add_development_dependency('rake', '>= 0.8.3')
  s.add_development_dependency('ramaze', '>= 2009.04')
  s.add_development_dependency('launchy', '>= 0.3.2')
  s.add_development_dependency('rcov', '>= 0.8.1.2.0')
  s.add_development_dependency('rubyforge', '>= 2.0.2')
  s.add_development_dependency('RedCloth', '>= 4.1.9')
  s.add_development_dependency('haml', '>= 3.0.12')
  s.add_development_dependency('builder', '>= 2.1.0')
  s.add_development_dependency('rdoc', '>= 2.4.3')
  s.add_development_dependency('coderay', '>= 0.8.312')
  s.add_development_dependency('erubis', '>= 2.6.5')
  s.add_development_dependency('rdiscount', '>= 1.3.5')
  s.add_development_dependency('archive-tar-minitar', '>= 0.5.2')

  s.require_path = 'lib'

  s.executables = ['webgen']
  s.default_executable = 'webgen'

  #### Documentation

  s.has_rdoc = true
  s.rdoc_options = ['--line-numbers', '--main', 'lib/webgen/website.rb']

  #### Author and project details

  s.author = 'Thomas Leitner'
  s.email = 't_leitner@gmx.at'
  s.homepage = "http://webgen.rubyforge.org"
  s.rubyforge_project = 'webgen'
end
