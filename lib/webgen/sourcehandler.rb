# -*- encoding: utf-8 -*-

require 'webgen/loggable'
require 'webgen/common'
require 'benchmark'

module Webgen

  # Namespace for all classes that handle source paths.
  #
  # Have a look at Webgen::SourceHandler::Base for details on how to implement a source handler
  # class.
  module SourceHandler

    autoload :Base, 'webgen/sourcehandler/base'
    autoload :Copy, 'webgen/sourcehandler/copy'
    autoload :Directory, 'webgen/sourcehandler/directory'
    autoload :Metainfo, 'webgen/sourcehandler/metainfo'
    autoload :Tags, 'webgen/sourcehandler/tags'
    autoload :Index, 'webgen/sourcehandler/index'
    autoload :Template, 'webgen/sourcehandler/template'
    autoload :Page, 'webgen/sourcehandler/page'
    autoload :Fragment, 'webgen/sourcehandler/fragment'
    autoload :Virtual, 'webgen/sourcehandler/virtual'
    autoload :Feed, 'webgen/sourcehandler/feed'
    autoload :Sitemap, 'webgen/sourcehandler/sitemap'
    autoload :Memory, 'webgen/sourcehandler/memory'

    # This class is used by Website to do the actual rendering of the website. It
    #
    # * collects all source paths using the source classes
    # * creates nodes using the source handler classes
    # * writes changed nodes out using an output class
    # * deletes old nodes
    class Main

      include WebsiteAccess
      include Loggable

      def initialize #:nodoc:
        website.blackboard.add_service(:create_nodes, method(:create_nodes))
        website.blackboard.add_service(:create_nodes_from_paths, method(:create_nodes_from_paths))
        website.blackboard.add_service(:source_paths, method(:find_all_source_paths))
        website.blackboard.add_listener(:node_meta_info_changed?, method(:meta_info_changed?))

        website.blackboard.add_listener(:before_node_deleted) do |node|
          unless node.is_fragment? || node['no_output'] || node.path == '/' || node == node.tree.dummy_root
            website.blackboard.invoke(:output_instance).delete(node.path)
          end
        end if website.config['output.do_deletion']
      end

      # Render the current website. Before the actual rendering is done, the sources are checked for
      # changes, i.e. nodes for deleted sources are deleted, nodes for new and changed sources are
      # updated.
      def render
        begin
          website.logger.mark_new_cycle if website.logger

          puts "Updating tree..."
          time = Benchmark.measure do
            website.cache.reset_volatile_cache
            update_tree
          end
          puts "...done in " + ('%2.4f' % time.real) + ' seconds'

          if !website.tree.root
            puts 'No source files found - maybe not a webgen website?'
            return nil
          end

          puts "Writing changed nodes..."
          time = Benchmark.measure do
            write_tree
          end
          puts "...done in " + ('%2.4f' % time.real) + ' seconds'
        end while website.tree.node_access[:alcn].any? {|name,node| node.flagged?(:created) || node.flagged?(:reinit)}
        :success
      rescue Webgen::Error
        raise
      rescue Exception => e
        raise Webgen::Error.new(e)
      end

      #######
      private
      #######

      # Update the <tt>website.tree</tt> by creating/reinitializing all needed nodes.
      def update_tree
        unused_paths = Set.new
        referenced_nodes = Set.new
        all_but_passive_paths = Set.new(find_all_source_paths.select {|name, path| !path.passive?}.collect {|name, path| name})
        num_pass = 0
        begin
          used_paths = all_but_passive_paths - unused_paths
          paths_to_use = Set.new
          nodes_to_delete = Set.new
          passive_nodes = Set.new

          website.tree.node_access[:alcn].each do |alcn, node|
            next if node == website.tree.dummy_root

            begin
              used_paths.delete(node.node_info[:src])

              src_path = find_all_source_paths[node.node_info[:src]]
              if !src_path
                nodes_to_delete << node
              elsif (!node.flagged?(:created) && src_path.changed?) || node.meta_info_changed?
                node.flag(:reinit)
                paths_to_use << node.node_info[:src]
              elsif node.changed?
                # nothing to be done here but method node.changed? has to be called
              end

              if src_path && src_path.passive?
                passive_nodes << node
              elsif src_path
                referenced_nodes += node.node_info[:used_meta_info_nodes] + node.node_info[:used_nodes]
              end
            rescue Webgen::Error => e
              e.alcn = node.alcn unless e.alcn
              raise
            rescue Exception => e
              raise Webgen::Error.new(e, nil, node)
            end
          end

          # add unused passive nodes to node_to_delete set
          unreferenced_passive_nodes, other_passive_nodes = passive_nodes.partition do |pnode|
            !referenced_nodes.include?(pnode.alcn)
          end
          refs = other_passive_nodes.collect {|n| (n.node_info[:used_meta_info_nodes] + n.node_info[:used_nodes]).to_a}.flatten
          unreferenced_passive_nodes.each {|n| nodes_to_delete << n if !refs.include?(n.alcn)}

          nodes_to_delete.each {|node| website.tree.delete_node(node)}
          used_paths.merge(paths_to_use)
          paths = create_nodes_from_paths(used_paths).collect {|n| n.node_info[:src]}
          unused_paths.merge(used_paths - paths)
          website.tree.node_access[:alcn].each {|name, node| website.tree.delete_node(node) if node.flagged?(:reinit)}
          website.cache.reset_volatile_cache
          num_pass += 1
          if num_pass >= 10
            raise Exception.new("Infinite loop detected after #{num_pass} iterations. The following paths are left used: #{used_paths.inspect}\nif you modified path.meta_info or node.meta_info, should should definitely NOT do that. It will void the meta info change detection, and detect the path/node as always changing.
            
            NOTE: SourceHandler::Base#page_from_path modifies path.meta_info. If path.meta_info is not changed in Sourcehandler@paths, then there will be a difference between the path.meta_info and the node.meta_info, and the node will always be detected as changed.
            it is just not allowed to call
              website.blackboard.invoke(:create_nodes, path, feed_source_handler) do
            from within a create_node because the create_nodes handler duplicates the path and prevents the path from being updated in Sourcehandler@paths
            
            ")
          end
        end until used_paths.empty?
      end

      # Write out all changed nodes of the <tt>website.tree</tt>.
      def write_tree
        output = website.blackboard.invoke(:output_instance)

        website.tree.node_access[:alcn].select do |name, node|
          use_node = (node != website.tree.dummy_root && node.flagged?(:dirty))
          node.unflag(:dirty_meta_info)
          node.unflag(:created)
          node.unflag(:dirty)
          use_node
        end.sort.each do |name, node|
          begin
            next if node['no_output'] || !(content = node.content)

            puts " "*4 + name, :verbose
            type = if node.is_directory?
                     :directory
                   elsif node.is_fragment?
                     :fragment
                   else
                     :file
                   end
            output.write(node.path, content, type)
          rescue Webgen::Error => e
            e.alcn = node.alcn unless e.alcn
            raise
          rescue Exception => e
            raise Webgen::RenderError.new(e, nil, node)
          end
        end
      end

      # Return a hash with all source paths.
      def find_all_source_paths
        if !defined?(@paths)
          active_source = Webgen::Source::Stacked.new(website.config['sources'].collect do |mp, name, *args|
                                                        [mp, Webgen::Common.const_for_name(name).new(*args)]
                                                      end)
          passive_source = Webgen::Source::Stacked.new(website.config['passive_sources'].collect do |mp, name, *args|
                                                         [mp, Webgen::Common.const_for_name(name).new(*args)]
                                                       end, true)
          passive_source.paths.each {|path| path.passive = true }
          source = Webgen::Source::Stacked.new([['/', active_source], ['/', passive_source]])

          @paths = {}
          source.paths.each do |path|
            if !(website.config['sourcehandler.ignore'].any? {|pat| File.fnmatch(pat, path, File::FNM_CASEFOLD|File::FNM_DOTMATCH)})
              #ap path.source_path => path #if path.source_path == "/Blog/index.index"
              @paths[path.source_path] = path
            end
          end
        end
        @paths
      end

      # Return only the subset of +paths+ which are handled by the source handler +name+.
      def paths_for_handler(name, paths)
        patterns = website.config['sourcehandler.patterns'][name]
        return [] if patterns.nil?

        options = (website.config['sourcehandler.casefold'] ? File::FNM_CASEFOLD : 0) |
          (website.config['sourcehandler.use_hidden_files'] ? File::FNM_DOTMATCH : 0) |
          File::FNM_PATHNAME
        find_all_source_paths.values_at(*paths).compact.select do |path|
          patterns.any? {|pat| File.fnmatch(pat, path, options)}
        end
      end

      # Use the source handlers to create nodes for the +paths+ in the <tt>website.tree</tt> and
      # return the nodes that have been created.
      def create_nodes_from_paths(paths)
        nodes = Set.new
        website.config['sourcehandler.invoke'].sort.each do |priority, shns|
          shns.each do |shn|
            sh = website.cache.instance(shn)
            handler_paths = paths_for_handler(shn, paths)
            handler_paths.sort {|a,b| a.path.length <=> b.path.length}.each do |path|
              if !website.tree[path.parent_path]
                nodes.merge(create_nodes_from_paths([path.parent_path]))
              end
              nodes += create_nodes(path, sh)
            end
          end
        end
        nodes
      end

      # Prepare everything to create from the +path+ using the +source_handler+. If a block is
      # given, the actual creation of the nodes is deferred to it. Otherwise the #create_node method
      # of the +source_handler+ is used. After the nodes are created, it is also checked if they
      # have all needed properties.
      def create_nodes(path, source_handler) #:yields: path
        raise Exception.new "Cannot create #{source_handler.class.name} node with a path that has modified meta information: #{path}\noriginal: #{path.meta_info.inspect}\nchanged:  #{path.meta_info_cached.inspect}" if path.meta_info_changed?
        path = path.dup
        path.meta_info = default_meta_info(path, source_handler.class.name)
        path.meta_info_cached = path.meta_info.dup
        puts "create_nodes(#{path}, #{source_handler})"
        #ap :meta_info_id => path.meta_info.object_id.to_s(16), :path => path
        #ap :default_meta_info => [path, source_handler.class.name], :mi_title => path.meta_info['title']
        #ap :create_node_path_meta_info => path.meta_info, :source_handler => source_handler.class.name
        website.cache[:sourcehandler_path_mi] ||= {}
        website.cache[:sourcehandler_path_mi][[path.path, source_handler.class.name]] = path.meta_info.dup
        ap :in_cache => website.cache[:sourcehandler_path_mi][[path.path, source_handler.class.name]], :id => website.cache[:sourcehandler_path_mi][[path.path, source_handler.class.name]].object_id.to_s(16)
        website.blackboard.dispatch_msg(:before_node_created, path)
        *nodes = if block_given?
                   yield(path)
                 else
                   source_handler.create_node(path)
                 end
        nodes = nodes.flatten.compact
        ap :in_cache => website.cache[:sourcehandler_path_mi][[path.path, source_handler.class.name]], :id => website.cache[:sourcehandler_path_mi][[path.path, source_handler.class.name]].object_id.to_s(16)
        nodes.each {|node| website.blackboard.dispatch_msg(:after_node_created, node)}
        nodes
      rescue Webgen::Error => e
        e.alcn = path unless e.alcn
        raise
      rescue Exception => e
        raise Webgen::NodeCreationError.new(e, source_handler.class.name, path)
      end

      # Return the default meta info for the pair of +path+ and +sh_name+.
      def default_meta_info(path, sh_name)
        path.meta_info.merge(website.config['sourcehandler.default_meta_info'][:all]).
          merge(website.config['sourcehandler.default_meta_info'][sh_name] || {})
      end

      # Check if the default meta information for +node+ has changed since the last run. But don't
      # take the node's path's +modified_at+ meta information into account since that changes on
      # every path change.
      def meta_info_changed?(node)
        path = node.node_info[:creation_path]

        old_mi_key = [path, node.node_info[:processor]]
        old_mi = website.cache[:sourcehandler_path_mi][old_mi_key]
        old_mi.delete('modified_at') unless old_mi.nil?
        new_mi_path = @paths[path] || Webgen::Path.new(path)
        new_mi = default_meta_info(new_mi_path, node.node_info[:processor])
        new_mi.delete('modified_at')
        if old_mi.nil?
          #old_mi = new_mi
          #website.cache[:sourcehandler_path_mi][old_mi_key] = old_mi
          #return true
          warn node.inspect
          warn old_mi_key.inspect
          raise Exception.new("#{node.node_info[:processor]}: internal error, node #{path} not in cache\nDid you use website.blackboard.invoke(:create_nodes, ...)? (this sets the cache).")
        end
        puts "meta_info_changed? #{node.inspect}"
        if old_mi != new_mi #or path == "/index.page"
          ap :path => new_mi_path
          ap :default_meta => new_mi, :old_meta => old_mi
          #ap :old => old_mi, :new => new_mi
          #ap :new_mi_path => new_mi_path.inspect, :processor => node.node_info[:processor], :default_meta => :new_mi
          #ap :paths_path => [path, @paths[path]]
          #ap :default_meta_info => [(@paths[path] || Webgen::Path.new(path)), node.node_info[:processor]], :mi_title => new_mi['title']
          #ap :node => node.inspect, :old => old_mi, :new => new_mi, :path => path, :processor => node.node_info[:processor]
        end
        node.flag(:dirty_meta_info) if !old_mi || old_mi != new_mi
      end

    end

  end

end
