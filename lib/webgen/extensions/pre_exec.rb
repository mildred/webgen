# -*- encoding: utf-8 -*-

module Webgen::Extension

  class PreExec

    include Webgen::Extension::Base

    def execute
      Dir.chdir(website.directory) do
        config.each do |cmd|
          puts "Execute #{cmd}"
          system cmd
        end
      end
    end

  end

end
