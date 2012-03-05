# -*- encoding: utf-8 -*-

module Webgen::SourceHandler

  # Source handler for creating atom and/or rss feeds.
  class Feed

    include Webgen::WebsiteAccess
    include Base

    def initialize # :nodoc:
      website.blackboard.add_listener(:node_changed?, method(:node_changed?))
    end

    # Create atom and/or rss feed files from +path+.
    def create_node(path, opts = {})
      opts[:page] ||= page_from_path(path, "feed")
      path.meta_info['link']       ||= path.parent_path
      path.meta_info['extensions'] ||= {}
      path.meta_info['site_url']   ||= website.config['website.url']
      path.meta_info['author']     ||= website.config['sourcehandler.feed.default_author']

      if !path.meta_info['author'] || !path.meta_info['site_url'] || (!path.meta_info['sub_nodes'] && !path.meta_info['entries'])
        raise Webgen::NodeCreationError.new("At least one of author/entries/site_url is missing",
                                            self.class.name, path)
      end

      if path.meta_info['sub_nodes']
        path.meta_info['sub_nodes'].each do |e|
          raise Exception.new "Missing node_info[:page] from entry #{e.inspect} for feed  #{path}" unless e.node_info[:page]
          raise Exception.new "Missing content block from entry #{e.inspect} for feed #{path}" if e.node_info[:page].blocks[path.meta_info['content_block_name'] || 'content'].nil?
        end
      end

      create_feed_node = lambda do |type|
        path.ext = path.meta_info['extensions'][type] || type
        super(path) do |node|
          node.node_info[:feed] = opts[:page]
          node.node_info[:feed_type] = type
        end
      end

      nodes = []
      nodes << create_feed_node['atom'] if path.meta_info['atom']
      nodes << create_feed_node['rss'] if path.meta_info['rss']

      nodes
    end

    # Return the rendered feed represented by +node+.
    def content(node)
      website.cache[[:sourcehandler_feed, node.node_info[:src]]] = feed_entries(node).map {|n| n.alcn}

      block_name = node.node_info[:feed_type] + '_template'
      if node.node_info[:feed].blocks.has_key?(block_name)
        node.node_info[:feed].blocks[block_name].render(Webgen::Context.new(:chain => [node])).content
      else
        chain = [node.resolve("/templates/#{node.node_info[:feed_type]}_feed.template"), node]
        node.node_info[:used_nodes] << chain.first.alcn
        chain.first.node_info[:page].blocks['content'].render(Webgen::Context.new(:chain => chain)).content
      end
    end

    # Return the entries for the feed +node+.
    def feed_entries(node)
      nr_items = (node['number_of_entries'].to_i == 0 ? 10 : node['number_of_entries'].to_i)
      sub_nodes = node['sub_nodes']

      unless sub_nodes
        patterns = [node['entries']].flatten.map {|pat| Webgen::Path.make_absolute(node.parent.alcn, pat)}
        sub_nodes = node.tree.node_access[:alcn].values.
          select {|node| patterns.any? {|pat| node =~ pat} && node.node_info[:page]}
      end

      sub_nodes.sort {|a,b| a['modified_at'] <=> b['modified_at']}.reverse[0, nr_items]
    end

    # Return the feed link URL for the feed +node+.
    def feed_link(node)
      Webgen::Node.url(File.join(node['site_url'], node.tree[node['link']].path), false)
    end

    # Return the site_url feed +node+.
    def site_url(node)
      node['site_url']
    end

    # Return the content of an +entry+ of the feed +node+.
    def entry_content(node, entry)
      entry.node_info[:page].blocks[node['content_block_name'] || 'content'].render(Webgen::Context.new(:chain => [entry])).content
    rescue
      nil
    end

    #######
    private
    #######

    # Check if the any of the nodes used by this feed +node+ have changed and then mark the node as
    # dirty.
    def node_changed?(node)
      return if node.node_info[:processor] != self.class.name
      entries = node.feed_entries
      node.flag(:dirty) if entries.map {|n| n.alcn } != website.cache[[:sourcehandler_feed, node.node_info[:src]]] ||
        entries.any? {|n| n.changed?}
    end

  end

end
