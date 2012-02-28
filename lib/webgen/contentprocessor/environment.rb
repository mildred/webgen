module Webgen::ContentProcessor

  class Environment
    attr_reader :context
      
    def initialize(context, opts = {})
      @context = context
    end
    
    def get_binding
      binding
    end

    def get_erb_binding
      require 'erb'
      extend(ERB::Util)
      binding
    end

    def html_link(path)
      path = path.alcn if path.kind_of? Webgen::Node
      tag = Webgen::Tag::Link.new
      tag.set_params 'tag.link.path' => path
      tag.call(nil, nil, @context)
    end
  
    def link_relative(path)
      path = path.alcn if path.kind_of? Webgen::Node
      tag = Webgen::Tag::Relocatable.new
      tag.set_params 'tag.relocatable.path' => path
      res = tag.call(nil, nil, @context)
      res
    end
    
    def link_absolute(path)
      path = path.path if path.kind_of? Webgen::Node
      Webgen::Node.url(path, true, :absolute_prefix => config['website.url'], :hide_index => true)
    end

    alias :link_rel   :link_relative
    alias :link_path  :link_relative
    alias :link_item  :link_relative
    alias :link_abs   :link_absolute

    def config
      Webgen::WebsiteAccess.website.config
    end

    def node
      @context.node
    end

    # See context/nodes.rb

    def content_node
      @context.content_node
    end

    def ref_node
      @context.ref_node
    end

    def dest_node
      @context.dest_node
    end
    
    def has_block?(name)
      block(name, :return_if_block_exists => true)
    end

    def block(name, attrs = {}, &proc)
      attrs[:name]  = name.to_s
      attrs[:chain] = [attrs[:chain]] if attrs[:chain].kind_of?(Webgen::Node)
      if attrs[:render]
        attrs[:chain] = @context[:chain][1..-1] unless attrs[:chain]
        attrs[:chain] = [attrs[:render]] + attrs[:chain]
      end
      if attrs[:chain].kind_of?(Array)
        attrs[:chain].map! do |item|
          if item.kind_of? String
            temp_node = @context.ref_node.resolve(item, @context.dest_node.lang)
            if temp_node.nil?
              raise Webgen::RenderError.new("Could not resolve <#{item}>",
                                            self.class.name, @context.dest_node,
                                            @context.ref_node, (options[:line_nr_proc].call if options[:line_nr_proc]))
            end
            temp_node
          else
            item
          end
        end
      end
      attrs[:node]     = attrs[:node].to_s     unless attrs[:node].nil?
      attrs[:notfound] = attrs[:notfound].to_s unless attrs[:notfound].nil?
      attrs[:dest]   ||= 'dest'
      attrs[:dest]     = attrs[:dest].to_s
      if proc
        notfound = attrs[:notfound]
        attrs[:notfound] = 'nil'
      end
      block = Webgen::ContentProcessor::Blocks.new
      result = block.render_block(@context, attrs)
      if proc
        if result.nil?
          result = ''
        else
          proc.call(result)
        end
      end
      result
    end

  end

end

