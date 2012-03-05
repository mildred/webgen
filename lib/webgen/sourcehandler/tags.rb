# -*- encoding: utf-8 -*-

module Webgen::SourceHandler

  # Handle tags, Create index nodes for each page having some tag
  class Tags

    include Base
    include Webgen::WebsiteAccess

    # Create the node for +path+. If the +path+ has the name of a content processor as the first
    # part in the extension, it is preprocessed.
    def create_node(path, opts = {})
      opts[:page] ||= page_from_path(path, "tags")
      block_name = path.meta_info['block_config_tags'] || "config_tags"
      data = YAML::load(opts[:page].get_block(block_name, "content").content) || {}
      tags = {}

      kind_attribute = data['kind_attribute']   || 'kind'
      tag_attributes = data['tag_attributes']   || ['tags']
      act_on         = [data['act_on']]         || []
      act_on         = act_on.flatten.delete_if(&:nil?)
      act_on_all     = data['act_on_all']       || act_on.empty?
      children_only  = data['children_only']    || false
      
      data['exclude_processors'] =
        [data['exclude_processors']].flatten || ["Webgen::SourceHandler::Tags"]
      data['exclude_processors'] = nil if data['exclude_processors'] == '~'

      parent = parent_node(path)
      parent.tree.node_access[:alcn].values.each do |n|
        next if children_only and not n.in_subtree_of?(parent)
        next unless act_on_all or act_on.include?(n[kind_attribute])
        next if data['exclude_processors'].include? n.node_info[:processor]
        next unless n['tag'].nil? # avoid recursivity
        tag_attributes.map { |a| n[a] }.delete_if(&:nil?).flatten.each do |tag|
          tags[tag] = [] unless tags.has_key? tag
          tags[tag] << n
        end
      end

      index_source_handler = website.cache.instance("Webgen::SourceHandler::Index")
      dir_handler = website.cache.instance('Webgen::SourceHandler::Directory')
      nodes = []

      nodes << super(path, :parent => parent) do |node|
        node.node_info[:config] = data
        node.node_info[:tags] = tags
        parent = node
      end

      # Create directory for all the tags
      path.set_path "#{path.parent_path}#{path.basename}/"
      nodes << website.blackboard.invoke(:create_nodes, path, dir_handler) do |cn_path|
        dir_handler.create_node(cn_path)
      end

      tags.each do |tag, tag_nodes|

        # Create a directory per tag
        t_path = path.dup
        t_path.set_path "#{path.path}#{tag}/"
        nodes_for_tag = website.blackboard.invoke(:create_nodes, t_path, dir_handler) do |cn_path|
          dir_handler.create_node(cn_path)
        end

        # Create index nodes in the tag directory
        t_path.set_path "#{path.path}#{tag}/index.index"
        nodes_for_tag << website.blackboard.invoke(:create_nodes, t_path, index_source_handler) do |cn_path|
          index_source_handler.create_node(cn_path, :nodes => tag_nodes, :meta => {'tag' => tag})
        end

        nodes_for_tag.flatten!
        nodes_for_tag.each do |node|
          node.node_info[:used_meta_info_nodes] << tag_nodes.map(&:alcn)
        end
        nodes << nodes_for_tag

      end

      nodes
    end

    def content(node)
      node.node_info[:tag]
    end

  end

end
