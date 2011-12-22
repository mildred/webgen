# -*- encoding: utf-8 -*-

module Webgen::SourceHandler

  # Handle tags, Create index nodes for each page having some tag
  class Tags

    include Base
    include Webgen::WebsiteAccess

    # Create the node for +path+. If the +path+ has the name of a content processor as the first
    # part in the extension, it is preprocessed.
    def create_node(path)
      page = page_from_path(path)
      data = YAML::load(page.blocks["content"].content) || {}
      tags = {}
      
      kind_attribute = data['kind_attribute'] || 'kind'
      tag_attributes = data['tag_attributes'] || ['tag', 'tags']
      act_on_all     = data['act_on_all']     || true
      act_on         = data['act_on']         || []
      
      parent = parent_node(path)
      parent.tree.node_access[:alcn].values.each do |n|
        if act_on_all or act_on.include?(n[kind_attribute])
          tag_attributes.map { |a| n[a] }.flatten.each do |tag|
            tags[tag] = [] unless tags.has_key? tag
            tags[tag] << n
          end
        end
      end

      parent_path = "#{path.parent_path}#{path.basename}/"
      nodes = []
      tags.each do |tag, tag_nodes|
        warn "#{parent_path}#{tag}"
        nodes << super(path, :parent => parent, :output_path => "#{parent_path}#{tag}") do |node|
          node.node_info[:config] = data
          node.node_info[:tag]    = tag
          node.node_info[:nodes]  = tag_nodes
        end
      end
      
      warn nodes.inspect
      # TODO: all the nodes have the same path, they should each have a different fragment
      # When we create the node, we should trasnform path to add a fragment
      # SourceHandler::Feed transform the path extension, but that's the same idea
      
      nodes
    end

    def content(node)
      node.node_info[:tag]
    end

  end

end
