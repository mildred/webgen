# -*- encoding: utf-8 -*-

module Webgen::SourceHandler

  # Simple source handler for copying files from the source tree, either verbatim or by applying a
  # content processor.
  class Index

    include Webgen::WebsiteAccess
    include Base

    # Create the node for +path+. If the +path+ has the name of a content processor as the first
    # part in the extension, it is preprocessed.
    def create_node(path)
      page = page_from_path(path)
      data = YAML::load(page.blocks["content"].content) || {}
      sub_nodes = []
      
      orders = {'newest-first' => :desc,
                'oldest-first' => :asc,
                'newest-last'  => :asc,
                'oldest-last'  => :desc,
                'asc'          => :asc,
                'desc'         => :desc}
      
      kind_attribute = data['kind_attribute']         || 'kind'
      act_on         = [data['act_on']].flatten       || []
      act_on_all     = data['act_on_all']             || act_on.empty?
      index_size     = data['index_size']             || 10
      index_order    = data['index_order']            || 'newest-first'
      index_order    = orders[index_order.downcase]   || :desc
      archive_size   = data['archive_size']           || 10
      archive_order  = data['archive_order']          || 'oldest-first'
      archive_order  = orders[archive_order.downcase] || :asc
      children_only  = data['children_only']          || true
      sort_key       = data['sort_key']               || 'created_at'
      page_basename  = data['page_basename']          || 'page_%d'
      page_start_at  = data['page_start_at']          || 1
      
      parent = parent_node(path)
      parent.tree.node_access[:alcn].values.each do |n|
        next if children_only and not n.in_subtree_of?(parent)
        next unless act_on_all or act_on.include?(n[kind_attribute])
        sub_nodes << n
      end
      
      sub_nodes.sort! do |a,b|
        if a[sort_key].nil?
          1
        elsif b[sort_key].nil?
          -1
        else
          a[sort_key] <=> b[sort_key]
        end
      end
      
      sub_nodes = {:asc => sub_nodes, :desc => sub_nodes.reverse}
      index_nodes = sub_nodes[index_order][0, index_size]
      pages_nodes = sub_nodes[archive_order]
      pages = []
      until pages_nodes.empty?
        pages << pages_nodes.slice!(0, archive_size)
      end
      
      # Create index node
      nodes = []
      nodes << super(path, :parent => parent) do |node|
        node.node_info[:config]    = data
        node.node_info[:sub_nodes] = index_nodes
        node.node_info[:page]      = page
      end

      # Create page nodes
      parent_path = path.parent_path
      pages.each_index do |i|
        basename = page_basename % (page_start_at + i)
        #p = Webgen::Path.new("#{parent_path}#{basename}", path.source_path)
        #p.meta_info = path.meta_info
        path.ext = basename
        outpath = "#{parent_path}#{basename}"
        outpath = output_path(parent, path)
        warn "#{path} --> #{outpath}"
        nodes << super(path, :parent => parent, :output_path => outpath) do |node|
          warn node.inspect
          node.node_info[:config]    = data
          node.node_info[:page_num]  = page_start_at + i
          node.node_info[:sub_nodes] = pages[i]
          node.node_info[:page]      = page
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

  end

end
