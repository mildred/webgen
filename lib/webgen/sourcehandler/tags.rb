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
      
      kind_attribute = data['kind_attribute']   || 'kind'
      tag_attributes = data['tag_attributes']   || ['tag', 'tags']
      act_on         = [data['act_on']].flatten || []
      act_on_all     = data['act_on_all']       || act_on.empty?
      children_only  = data['children_only']    || false
      
      parent = parent_node(path)
      parent.tree.node_access[:alcn].values.each do |n|
        next if children_only and not n.in_subtree_of?(parent)
        next unless act_on_all or act_on.include?(n[kind_attribute])
        tag_attributes.map { |a| n[a] }.delete_if(&:nil?).flatten.each do |tag|
          tags[tag] = [] unless tags.has_key? tag
          tags[tag] << n
        end
      end
      
      # Create parent node
      nodes = []
      nodes << super(path, :parent => parent) do |node|
        node.node_info[:config] = data
        node.node_info[:tag]    = nil
        node.node_info[:nodes]  = []
        parent = node
      end

      return nodes

      # Create child nodes
      parent_path = "#{path.parent_path}#{path.basename}/"
      tags.each do |tag, tag_nodes|
        p = Webgen::Path.new("#{path}##{tag}", path.source_path)
        p.meta_info = path.meta_info
        nodes << super(p, :parent => parent, :output_path => "#{parent_path}#{tag}") do |node|
          node.node_info[:config] = data
          node.node_info[:tag]    = tag
          node.node_info[:nodes]  = tag_nodes
        end
      end
      
      nodes
    end

    def content(node)
      node.node_info[:tag]
    end
    
    def output_path(parent, path)
      res = super(parent, path)
      warn "Tags#output_path(#{parent}, #{path}) = #{res}"
      res
    end

  end

end
