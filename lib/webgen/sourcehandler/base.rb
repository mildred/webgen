# -*- encoding: utf-8 -*-

require 'webgen/websiteaccess'
require 'webgen/loggable'
require 'webgen/page'

module Webgen::SourceHandler

  # This module should be included in every source handler as it provides the default methods for
  # creating nodes.
  #
  # == Implementing Source Handlers
  #
  # A source handler is a webgen extension that processes source paths to create nodes and that
  # provides the rendered content of these nodes. The nodes are later written to the output
  # location. This can range from simply copying a path from the source to the output location to
  # generating a whole set of nodes from one input path!
  #
  # The paths that are handled by a source handler are specified via path patterns (see
  # below). During a webgen run the #create_node method for each source paths that matches a
  # specified path pattern is called. And when it is time to write out the node, the #content
  # method is called to retrieve the rendered content.
  #
  # A source handler must not take any parameters on initialization and when this module is not
  # mixed in, the methods #create_node and #content need to be defined. Also, a source handler does
  # not need to reside under the Webgen::SourceHandler namespace but all shipped ones do.
  #
  # This base class provides useful default implementations of methods that are used by nearly all
  # source handler classes:
  # * #create_node
  # * #output_path
  # * #node_exists?
  #
  # It also provides other utility methods:
  # * #page_from_path
  # * #content
  # * #parent_node
  #
  # == Nodes Created for Paths
  #
  # The main functions of a source handler class are to create one or more nodes for a source path
  # and to provide the content of these nodes. To achieve this, certain information needs to be set
  # on a created node. If you use the +create_node+ method provided by this base class, you don't
  # need to set them explicitly because this is done by the method:
  #
  # [<tt>node_info[:processor]</tt>] Has to be set to the class name of the source handler. This is
  #                                  used by the Node class: all unknown method calls are forwarded
  #                                  to the node processor.
  # [<tt>node_info[:src]</tt>] Has to be set to the string version of the path that lead to the
  #                            creation of the node.
  # [<tt>node_info[:creation_path]</tt>] Has to be set to the string version of the path that is
  #                                      used to create the path.
  # [<tt>meta_info['no_output']</tt>] Has to be set to +true+ on nodes that are used during a
  #                                   webgen run but do not produce an output file.
  # [<tt>meta_info['modified_at']</tt>] Has to be set to the current time if not already set
  #                                     correctly (ie. if not a Time object).
  #
  # If <tt>meta_info['draft']</tt> is set on a path, then no node should be created in +create_node+
  # and +nil+ has to be returned.
  #
  # Note: The difference between +:src+ and +:creation_path+ is that a creation path
  # need not have an existing source path representation. For example, fragments created from a page
  # source path have a different +:creation_path+ which includes the fragment part.
  #
  # Additional information that is used only for processing purposes should be stored in the
  # #node_info hash of a node as the #meta_info hash is reserved for real node meta information and
  # should not be changed once the node is created.
  #
  # == Output Path Names
  #
  # The method for creating an output path name for a source path is stored in the meta information
  # +output_path+. If you don't use the provided method +output_path+, have a look at its
  # implementation to see how to an output path gets created. Individual output path creation
  # methods are stored as methods in the OutputPathHelpers module.
  #
  # == Path Patterns and Invocation order
  #
  # Path patterns define which paths are handled by a specific source handler. These patterns are
  # specified in the <tt>sourcehandler.patterns</tt> configuration hash as a mapping from the source
  # handler class name to an array of path patterns. The patterns need to have a format that
  # <tt>Dir.glob</tt> can handle. You can use the configuration helper +patterns+ to set this (is
  # shown in the example below).
  #
  # Specifying a path pattern does not mean that webgen uses the source handler. One also needs to
  # provide an entry in the configuration value <tt>sourcehandler.invoke</tt>. This is a hash that
  # maps the invocation rank (a number) to an array of source handler class names. The lower the
  # invocation rank the earlier the specified source handlers are used.
  #
  # The default invocation ranks are:
  # [1] Early. Normally there is no need to use this rank.
  # [5] Standard. This is the rank the normal source handler should use.
  # [9] Late. This rank should be used by source handlers that operate on/use already created nodes
  #     and need to ensure that these nodes are available.
  #
  # == Default Meta Information
  #
  # Each source handler can define default meta information that gets automatically set on the
  # source paths that are passed to the #create_node method.
  #
  # The default meta information is specified in the <tt>sourcehandler.default_meta_info</tt>
  # configuration hash as a mapping from the source handler class name to the meta information
  # hash.
  #
  # == Sample Source Handler Class
  #
  # Following is a simple source handler class example which copies paths from the source to
  # the output location modifying the extension:
  #
  #   class SimpleCopy
  #
  #     include Webgen::SourceHandler::Base
  #     include Webgen::WebsiteAccess
  #
  #     def create_node(path)
  #       path.ext += '.copied'
  #       super(path)
  #     end
  #
  #     def content(node)
  #       website.blackboard.invoke(:source_paths)[node.node_info[:src]].io
  #     end
  #
  #   end
  #
  #   WebsiteAccess.website.config.patterns('SimpleCopy' => ['**/*.jpg', '**/*.png'])
  #   WebsiteAccess.website.config.sourcehandler.invoke[5] << 'SimpleCopy'
  #
  module Base

    # This module is used for defining all methods that can be used for creating output paths.
    #
    # All public methods of this module are considered to be output path creation methods and must
    # have the following parameters:
    #
    # [+parent+] the parent node
    # [+path+] the path for which the output name should be created
    # [+use_lang_part+] controls whether the output path name has to include the language part
    module OutputPathHelpers

      # Default method for creating an output path for +parent+ and source +path+.
      #
      # The automatically set parameter +style+ (which uses the meta information +output_path_style+
      # from the path's meta information hash) defines how the output name should be built (more
      # information about this in the user documentation).
      def standard_output_path(parent, path, use_lang_part, style = path.meta_info['output_path_style'])
        parent = parent.parent while parent.is_fragment?
        
        ctime_parts = {}
        ctime = path.meta_info['created_at']
        if ctime.kind_of?(Time)
          ctime_parts[:year]  = ctime.year.to_s.rjust(4, '0')
          ctime_parts[:month] = ctime.month.to_s.rjust(2, '0')
          ctime_parts[:day]   = ctime.day.to_s.rjust(2, '0')
        end

        result = output_path_fragment(style, path, ctime_parts.merge(
          :lang   => use_lang_part ? path.meta_info['lang'] : '',
          :ext    => path.ext.empty? ? '' : '.' + path.ext,
          :parent => parent.path))
        result
      end
      
    private

      def output_path_fragment(part, path, specials = {})
        case part
          when String  then part
          when Symbol  then
            if specials[part]
              specials[part]
            elsif part.to_s[0..0] == "_"
              path.meta_info[part.to_s[1..-1]]
            else
              path.send(part)
            end
          when Array   then
            res = part.map { |p| output_path_fragment(p, path, specials) }
            res.join('')
          when Hash    then
            cond = nil
            if not part['if'].nil? then
              cond = output_path_fragment(part['if'], path, specials)
            elsif not part['ifnot'].nil? then
              cond = output_path_fragment(part['ifnot'], path, specials) ? false : true
            elsif not part['ifeq'].nil? then
              cond = part['ifeq'].map { |p| output_path_fragment(p, path, specials) }
              cond = cond[0] == cond[1]
            elsif not part['ifne'].nil? then
              cond = part['ifne'].map { |p| output_path_fragment(p, path, specials) }
              cond = cond[0] != cond[1]
            end
            if not cond.nil?
              if cond
                output_path_fragment(part['then'], path, specials)
              else
                output_path_fragment(part['else'], path, specials)
              end
            elsif not part['regexp'].nil?
              subject = output_path_fragment(part['subject'], path, specials) || ''
              regexp  = output_path_fragment(part['regexp'], path, specials)
              replace = output_path_fragment(part['replace'], path, specials) || ''
              regexp = Regexp.new(regexp)
              subject.gsub(regexp, replace)
            elsif not part['pattern'].nil?
              subject = output_path_fragment(part['subject'], path, specials)
              pattern = output_path_fragment(part['pattern'], path, specials)
              replace = output_path_fragment(part['replace'], path, specials) || ''
              subject.gsub(pattern, replace)
            else
              ''
            end
          else
            ''
        end
      end

    end

    include Webgen::Loggable
    include OutputPathHelpers

    # Construct the output name for the given +path+ and +parent+. First it is checked if a node
    # with the constructed output name already exists. If it exists, the language part is forced to
    # be in the output name and the resulting output name is returned.
    def output_path(parent, path)
      method = path.meta_info['output_path'] + '_output_path'
      use_lang_part = if path.meta_info['lang'].nil? # unlocalized files never get a lang in the filename!
                        false
                      else
                        Webgen::WebsiteAccess.website.config['sourcehandler.default_lang_in_output_path'] ||
                          Webgen::WebsiteAccess.website.config['website.lang'] != path.meta_info['lang']
                      end
      if OutputPathHelpers.public_instance_methods(false).map {|c| c.to_s}.include?(method)
        name = send(method, parent, path, use_lang_part)
        name += '/'  if path.path =~ /\/$/ && name !~ /\/$/
        if (node = node_exists?(path, name)) && node.lang != path.meta_info['lang']
          name = send(method, parent, path, (path.meta_info['lang'].nil? ? false : true))
          name += '/'  if path.path =~ /\/$/ && name !~ /\/$/
        end
        name
      else
        raise Webgen::NodeCreationError.new("Unknown method for creating output path: #{path.meta_info['output_path']}",
                                            self.class.name, path)
      end
    end

    # Check if the node alcn and output path which would be created by #create_node exist. The
    # +output_path+ to check for can individually be set.
    def node_exists?(path, output_path = self.output_path(parent_node(path), path))
      Webgen::WebsiteAccess.website.tree[path.alcn] || (!path.meta_info['no_output'] && Webgen::WebsiteAccess.website.tree[output_path, :path])
    end

    # Create a node from +path+ if it does not already exists or re-initalize an already existing
    # node. The found node or the newly created node is returned afterwards. +nil+ is returned if no
    # node can be created (e.g. when <tt>path.meta_info['draft']</tt> is set).
    #
    # The +options+ parameter can be used for providing the optional parameters:
    #
    # [<tt>:parent</tt>] The parent node under which the new node should be created. If this is not
    #                    specified (the usual case), the parent node is determined by the
    #                    #parent_node method.
    #
    # [<tt>:output_path</tt>] The output path that should be used for the node. If this is not
    #                         specified (the usual case), the output path is determined via the
    #                         #output_path method.
    #
    # Some additional node information like <tt>:src</tt> and <tt>:processor</tt> is set and the
    # meta information is checked for validness. The created/re-initialized node is yielded if a
    # block is given.
    def create_node(path, options = {})
      return nil if path.meta_info['draft']
      parent = options[:parent] || parent_node(path)
      output_path = options[:output_path] || self.output_path(parent, path)
      node = node_exists?(path, output_path)

      if node && (node.node_info[:src] != path.source_path || node.node_info[:processor] != self.class.name)
        log(:warn) { "Node already exists: source = #{path.source_path} | path = #{node.path} | alcn = #{node.alcn}"}
        return node #TODO: think! should nil be returned?
      elsif !node
        node = Webgen::Node.new(parent, output_path, path.cn, path.meta_info)
      elsif node.flagged?(:reinit)
        node.reinit(output_path, path.meta_info)
      else
        return node
      end

      if !node['modified_at'].kind_of?(Time)
        log(:warn) { "Meta information 'modified_at' set to current time in <#{node}> since its value '#{node['modified_at']}' was of type #{node['modified_at'].class}" } unless node['modified_at'].nil?
        node['modified_at'] = Time.now
      end
      node.node_info[:src] = path.source_path
      node.node_info[:creation_path] = path.path
      node.node_info[:processor] = self.class.name
      yield(node) if block_given?
      node
    end

    # Return the content of the given +node+. If the return value is not +nil+ then the node gets
    # written, otherwise it is ignored.
    #
    # This default +content+ method just returns +nil+.
    def content(node)
      nil
    end

    # Utility method for creating a Webgen::Page object from the +path+. Also updates
    # <tt>path.meta_info</tt> with the meta info from the page.
    def page_from_path(path, meta_block_name=nil)
      begin
        page = Webgen::Page.from_data(path.io.data, path.meta_info)
        page.parse_meta_block(meta_block_name) if meta_block_name
      rescue Webgen::Page::FormatError => e
        raise Webgen::NodeCreationError.new("Error reading source path: #{e.message}",
                                            self.class.name, path)
      end
      path.meta_info = page.meta_info
      page
    end

    # Return the parent node for the given +path+.
    def parent_node(path)
      parent_dir = (path.parent_path == '' ? '' : Webgen::Path.new(path.parent_path).alcn)
      if !(parent = Webgen::WebsiteAccess.website.tree[parent_dir])
        raise Webgen::NodeCreationError.new("The needed parent path <#{parent_dir}> does not exist",
                                            self.class.name, path)
      end
      parent
    end

    # Create node using other SourceHandlers
    def create_sub_nodes(source_handler, path, opts={}) # yield
      source_handler = source_handler.class.name unless source_handler.kind_of? String
      sh = website.cache.instance(source_handler)
      path = path.dup
      path.ext = opts[:ext]           unless opts[:ext].nil? or opts[:ext].empty?
      path.basename = opts[:basename] unless opts[:basename].nil? or opts[:basename].empty?
      path.set_path opts[:fullname]   unless opts[:fullname].nil? or opts[:fullname].empty?
      website.blackboard.invoke(:create_nodes, path, sh) do |sub_path|
        yield sub_path, sh
      end
    end

  end

end
