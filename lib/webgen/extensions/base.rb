# -*- encoding: utf-8 -*-

module Webgen::Extension

  module Base

    attr_reader :config
    attr_reader :website

    def initialize(website, config)
      @website = website
      @config  = config
    end

    def execute
    end

  end

end
