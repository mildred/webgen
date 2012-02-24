# -*- encoding: utf-8 -*-

module Webgen::SourceHandler

  # Simple source handler for copying files from the source tree, either verbatim or by applying a
  # content processor.
  class Index

    include Webgen::WebsiteAccess
    include Base

    # Create the node for +path+. If the +path+ has the name of a content processor as the first
    # part in the extension, it is preprocessed.
    def create_node(path, opts = {})
      opts[:page] ||= page_from_path(path)
      block_name = path.meta_info['block_config_index'] || "config_index"
      data = YAML::load(opts[:page].get_block(block_name, "content").content) || {}
      cfg = get_config(data)

      kind_attribute = cfg[:kind_attribute]
      act_on         = cfg[:act_on]
      act_on_all     = cfg[:act_on_all]
      index_size     = cfg[:index_size]
      index_order    = cfg[:index_order]
      archive_size   = cfg[:archive_size]
      archive_order  = cfg[:archive_order]
      children_only  = cfg[:children_only]
      sort_key       = cfg[:sort_key]
      page_basename  = cfg[:page_basename]
      page_start_at  = cfg[:page_start_at]
      extension      = cfg[:extension]

      # Determine all sub nodes
      sub_nodes = []
      opts[:parent] ||= parent_node(path)
      opts[:parent].tree.node_access[:alcn].values.each do |n|
        next if children_only and not n.in_subtree_of?(opts[:parent])
        next unless act_on_all or act_on.include?(n[kind_attribute])
        sub_nodes << n
      end

      # Sort sub nodes
      sub_nodes.sort! do |a,b|
        if a[sort_key].nil?
          1
        elsif b[sort_key].nil?
          -1
        else
          a[sort_key] <=> b[sort_key]
        end
      end

      # Determine nodes for the index and the different pages
      sub_nodes = {:asc => sub_nodes, :desc => sub_nodes.reverse}
      index_nodes = sub_nodes[index_order][0, index_size]
      pages_nodes = sub_nodes[archive_order].dup
      pages = []
      until pages_nodes.empty?
        pages << pages_nodes.slice!(0, archive_size)
      end

      # Construct feeds
      nodes = []
      feeds = {}
      feed_source_handler = website.cache.instance("Webgen::SourceHandler::Feed")
      [:atom, :rss].each do |feed|
        next if cfg[feed].nil?
        tmp = cfg[feed].split(".", 2)
        nodes << create_sub_nodes(
            "Webgen::SourceHandler::Feed", path,
            :basename => tmp.first, :ext => tmp.last) do |ci_path, sh|
          ci_path.meta_info.merge! cfg[:feed_cfg]
          ci_path.meta_info['atom'] = false
          ci_path.meta_info['rss']  = false
          ci_path.meta_info[feed.to_s] = true
          ci_path.meta_info['sub_nodes'] = sub_nodes[:asc].delete_if { |n| n.node_info[:page].nil? }
          ci_path.meta_info['extensions'] = {feed.to_s => ci_path.ext}
          n = sh.create_node(ci_path, :page => opts[:page])
          feeds[feed] = n.first
          n
        end
      end

      # Create index node
      path.ext = extension
      nodes << super(path, :parent => opts[:parent]) do |node|
        node.node_info[:config]    = cfg
        node.node_info[:data]      = data
        node.node_info[:sub_nodes] = index_nodes
        node.node_info[:page]      = opts[:page]
        node.node_info.merge! feeds
      end

      # Create page nodes
      parent_path = path.parent_path
      pages.each_index do |i|
        basename = page_basename % (page_start_at + i)
        path.basename = basename
        path.ext = extension
        path.meta_info[:page] = page_start_at + i
        outpath = output_path(opts[:parent], path)
        nodes << super(path, :parent => opts[:parent], :output_path => outpath) do |node|
          node.node_info[:config]    = cfg
          node.node_info[:data]      = data
          node.node_info[:page_num]  = page_start_at + i
          node.node_info[:sub_nodes] = pages[i]
          node.node_info[:page]      = opts[:page]
          node.node_info.merge! feeds
        end
      end

      nodes
    end

    def content(node)
      chain = website.blackboard.invoke(:templates_for_node, node)
      chain << node

      node.node_info[:used_nodes] << chain.first.alcn
      context = chain.first.node_info[:page].blocks["content"].render(Webgen::Context.new(:chain => chain))
      context.content
    end

  private

    def get_config(data)
      data = data || {}

      orders = {'newest-first' => :desc,
                'oldest-first' => :asc,
                'newest-last'  => :asc,
                'oldest-last'  => :desc,
                'asc'          => :asc,
                'desc'         => :desc}

      cfg = {}

      cfg[:kind_attribute] = data['kind_attribute']   || 'kind'
      cfg[:act_on]         = data['act_on']           || []
      cfg[:act_on_all]     = data['act_on_all']       || cfg[:act_on].empty?
      cfg[:index_size]     = data['index_size']       || 10
      cfg[:index_order]    = data['index_order']      || 'newest-first'
      cfg[:archive_size]   = data['archive_size']     || 10
      cfg[:archive_order]  = data['archive_order']    || 'oldest-first'
      cfg[:children_only]  = data['children_only']    || true
      cfg[:sort_key]       = data['sort_key']         || 'created_at'
      cfg[:page_basename]  = data['page_basename']    || 'page_%d'
      cfg[:page_start_at]  = data['page_start_at']    || 1
      cfg[:extension]      = data['extension']        || 'html'
      cfg[:atom]           = data['feed.atom']        || 'atom.xml'
      cfg[:rss]            = data['feed.rss']         || 'rss.xml'
      cfg[:feed_cfg]       = data['feed.config']      || {}

      cfg[:act_on]         = [cfg[:act_on]].flatten
      cfg[:index_order]    = orders[cfg[:index_order].downcase]   || :desc
      cfg[:archive_order]  = orders[cfg[:archive_order].downcase] || :asc
      cfg[:atom]           = nil if cfg[:atom] == "~"
      cfg[:rss]            = nil if cfg[:rss] == "~"

      cfg
    end

  end

end
