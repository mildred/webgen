# -*- encoding: utf-8 -*-

require 'test/unit'
require 'helper'
require 'webgen/websiteaccess'
require 'webgen/contentprocessor'

class TestContentProcessorRedCloth < Test::Unit::TestCase

  include Test::WebsiteHelper

  def test_call
    @obj = Webgen::ContentProcessor::RedCloth.new
    node = Webgen::Node.new(Webgen::Tree.new.dummy_root, '/', '/')
    context = Webgen::Context.new(:content => "h1. header\n\nthis\nis\nsome\ntext", :chain => [node])
    assert_equal("<h1>header</h1>\n<p>this\nis\nsome\ntext</p>", @obj.call(context).content)

    context.content = "h1. header\n\nthis\nis\nsome\ntext"
    @website.config['contentprocessor.redcloth.hard_breaks'] = true
    assert_equal("<h1>header</h1>\n<p>this<br />\nis<br />\nsome<br />\ntext</p>", @obj.call(context).content)

    def @obj.require(lib); raise LoadError; end
    assert_raise(Webgen::LoadError) { @obj.call(context) }
  end

end
