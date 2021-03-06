# -*- encoding: utf-8 -*-

require 'webgen/tag'
require 'webgen/websiteaccess'

module Webgen::Common

  # This class provides functionality for creating sitemaps and checking if a sitemap has changed.
  class Sitemap

    include Webgen::WebsiteAccess

    def initialize #:nodoc:
      website.blackboard.add_listener(:node_changed?, method(:node_changed?))
    end

    # Return the sitemap tree as Webgen::Tag::Menu::MenuNode created for the +node+ in the language
    # +lang+ using the provided +options+ which can be any configuration option starting with
    # <tt>common.sitemap</tt>.
    def create_sitemap(node, lang, options)
      @options = options
      tree = recursive_create(nil, node.tree.root, lang).sort!
      @options = nil
      (node.node_info[:common_sitemap] ||= {})[[options.to_a.sort, lang]] = tree.to_lcn_list
      tree
    end

    #######
    private
    #######

    # Recursively create the sitemap.
    def recursive_create(parent, node, lang, in_sitemap = true)
      mnode = Webgen::Tag::Menu::MenuNode.new(parent, node)
      node.children.map do |n|
        sub_in_sitemap = in_sitemap?(n, lang)
        [(!n.children.empty? || sub_in_sitemap ? n : nil), sub_in_sitemap]
      end.each do |n, sub_in_sitemap|
        next if n.nil?
        sub_node = recursive_create(mnode, n, lang, sub_in_sitemap)
        mnode.children << sub_node unless sub_node.nil?
      end
      (mnode.children.empty? && !in_sitemap ? nil : mnode)
    end

    # Return +true+ if the +child+ of the +node+ is in the sitemap for the language +lang+.
    def in_sitemap?(child, lang, allow_index_file = false)
      ((option('common.sitemap.used_kinds').empty? || option('common.sitemap.used_kinds').include?(child['kind']) ||
        (child.routing_node(lang, false) != child && in_sitemap?(child.routing_node(lang), lang, true))) &&
       (option('common.sitemap.any_lang') || child.lang.nil? || child.lang == lang) &&
       (!option('common.sitemap.honor_in_menu') || child['in_menu']) &&
       (allow_index_file || child.parent == child.tree.root || child.parent.routing_node(lang) != child))
    end

    # Retrieve the configuration option value for +name+. The value is taken from the current
    # configuration options hash if +name+ is specified there or from the website configuration
    # otherwise.
    def option(name)
      (@options && @options.has_key?(name) ? @options[name] : website.config[name])
    end

    # Check if the sitemaps for +node+ have changed.
    def node_changed?(node)
      return if !node.node_info[:common_sitemap]

      node.node_info[:common_sitemap].each do |(options, lang), cached_tree|
        @options = options.to_hash
        tree = recursive_create(nil, node.tree.root, lang).sort!.to_lcn_list
        @options = nil

        if (tree != cached_tree) ||
            (tree.flatten.any? do |alcn|
               (n = node.tree[alcn]) && (r = n.routing_node(lang)) && r.meta_info_changed?
             end)
          node.flag(:dirty)
          break
        end
      end
    end

  end

end
