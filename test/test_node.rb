# -*- encoding: utf-8 -*-

require 'test/unit'
require 'helper'
require 'webgen/node'
require 'webgen/tree'

class TestNode < Test::Unit::TestCase

  include Test::WebsiteHelper

  def setup
    super
    @tree = @website.tree
  end

  def create_default_nodes
    {
      :root => node = Webgen::Node.new(@tree.dummy_root, '/', '/'),
      :somename_en => child_en = Webgen::Node.new(node, '/somename.en.html', 'somename.html', {'lang' => 'en', 'title' => 'somename en'}),
      :somename_de => child_de = Webgen::Node.new(node, '/somename.de.html', 'somename.html', {'lang' => 'de', 'title' => 'somename de', 'sort_test' => 1}),
      :other => Webgen::Node.new(node, '/other.html', 'other.html', {'title' => 'other', 'sort_test' => 5}),
      :other_en => Webgen::Node.new(node, '/other1.html', 'other.html', {'lang' => 'en', 'title' => 'other en', 'sort_test' => 4}),
      :somename_en_frag => frag_en = Webgen::Node.new(child_en, '/somename.en.html#frag', '#othertest', {'title' => 'frag'}),
      :somename_de_frag => Webgen::Node.new(child_de, '/somename.de.html#frag', '#othertest', {'title' => 'frag'}),
      :somename_en_fragnest => Webgen::Node.new(frag_en, '/somename.en.html#fragnest/', '#nestedpath', {'title' => 'fragnest'}),
      :dir => dir = Webgen::Node.new(node, '/dir/', 'dir/', {'title' => 'dir'}),
      :dir_file => dir_file = Webgen::Node.new(dir, '/dir/file.html', 'file.html', {'title' => 'file'}),
      :dir_file_frag => Webgen::Node.new(dir_file, '/dir/file.html#frag', '#frag', {'title' => 'frag'}),
      :dir2 => dir2 = Webgen::Node.new(node, '/dir2/', 'dir2/', {'index_path' => 'index.html', 'title' => 'dir2'}),
      :dir2_index_en => Webgen::Node.new(dir2, '/dir2/index.html', 'index.html',
                                         {'lang' => 'en', 'routed_title' => 'routed', 'title' => 'index en', 'sort_info' => 1}),
      :dir2_index_de => Webgen::Node.new(dir2, '/dir2/index.de.html', 'index.html',
                                         {'lang' => 'de', 'routed_title' => 'routed_de', 'title' => 'index de', 'sort_info' => 2}),
    }
  end

  def test_initialize_and_reinit
    check_proc = proc do |node, parent, path, cn, lcn, alcn, lang, mi|
      assert_equal(parent, node.parent)
      assert_equal(path, node.path)
      assert_equal(cn, node.cn)
      assert_equal(lcn, node.lcn)
      assert_equal(alcn, node.alcn)
      assert_equal(lang, node.lang)
      assert_kind_of(Webgen::Language, node.lang) if node.lang
      assert(node.flagged?(:dirty))
      assert(node.flagged?(:created))
      assert_equal(mi, node.meta_info)
      assert_equal({:used_nodes => Set.new, :used_meta_info_nodes => Set.new}, node.node_info)
      mi.each {|k,v| assert_equal(v, node[k])}
    end

    node = Webgen::Node.new(@tree.dummy_root, '/', '/', {'lang' => 'de', :test => :value})
    check_proc.call(node, @tree.dummy_root, '/', '/', '/', '/', nil, {:test => :value})

    child = Webgen::Node.new(node, 'somename.html', 'somename.html',  {'lang' => 'de'})
    check_proc.call(child, node, 'somename.html', 'somename.html', 'somename.de.html',
                    '/somename.de.html', 'de', {})

    ['http://webgen.rubyforge.org', 'c:\\test'].each_with_index do |abspath, index|
      cn = 'test' + index.to_s + '.html'
      c = Webgen::Node.new(node, abspath, cn)
      check_proc.call(c, node, abspath, cn, cn, '/' + cn, nil, {})
    end

    child.reinit('somename.en.html', {'lang' => 'de', 'title' => 'test'})
    check_proc.call(child, node, 'somename.en.html', 'somename.html', 'somename.de.html',
                    '/somename.de.html', 'de', {'title' => 'test'})
  end

  def test_type_checkers
    nodes = create_default_nodes
    assert(nodes[:root].is_directory?)
    assert(nodes[:somename_en].is_file?)
    assert(nodes[:somename_en_frag].is_fragment?)
    assert(nodes[:root].is_root?)
    assert(!nodes[:somename_en].is_root?)
    assert(nodes[:somename_en_fragnest].is_fragment?)
    assert(!nodes[:somename_en_fragnest].is_directory?)
  end

  def test_meta_info_assignment
    node = Webgen::Node.new(@tree.dummy_root, 'test/', 'test', {'lang' => 'de', :test => :value})
    node[:test] = :newvalue
    node[:other] = :value
    assert_equal(:newvalue, node[:test])
    assert_equal(:value, node[:other])
  end

  def test_flags
    node = Webgen::Node.new(@tree.dummy_root, 'test/', 'test', {'lang' => 'de', :test => :value})
    assert(node.flagged?(:created))
    assert(node.flagged?(:dirty))
    node.unflag(:dirty)
    assert(!node.flagged?(:dirty))
    node.flag(:a, :b, :c)
    assert(node.flagged?(:a))
    assert(node.flagged?(:b))
    assert(node.flagged?(:c))
    node.unflag(:a, :b, :c)
    assert(!node.flagged?(:a))
    assert(!node.flagged?(:b))
    assert(!node.flagged?(:c))
  end

  def test_in_lang
    nodes = create_default_nodes

    assert_equal(nodes[:somename_de], nodes[:somename_en].in_lang('de'))
    assert_equal(nodes[:somename_en], nodes[:somename_en].in_lang('en'))
    assert_equal(nodes[:somename_en], nodes[:somename_de].in_lang('en'))
    assert_equal(nil, nodes[:somename_de].in_lang('fr'))
    assert_equal(nil, nodes[:somename_en].in_lang(nil))

    assert_equal(nodes[:other_en], nodes[:other].in_lang('en'))
    assert_equal(nodes[:other], nodes[:other].in_lang('de'))
    assert_equal(nodes[:other], nodes[:other].in_lang(nil))
    assert_equal(nodes[:other], nodes[:other_en].in_lang(nil))
    assert_equal(nodes[:other], nodes[:other_en].in_lang('de'))

    assert_equal(nil, nodes[:somename_en_frag].in_lang(nil))
    assert_equal(nodes[:somename_en_frag], nodes[:somename_en_frag].in_lang('en'))
    assert_equal(nodes[:somename_de_frag], nodes[:somename_en_frag].in_lang('de'))
  end

  def test_resolve
    nodes = create_default_nodes

    [nodes[:root], nodes[:somename_de], nodes[:somename_en], nodes[:other]].each do |n|
      assert_equal(nil, n.resolve('somename.html', nil))
      assert_equal(nodes[:somename_en], n.resolve('somename.html', 'en'))
      assert_equal(nodes[:somename_de], n.resolve('somename.html', 'de'))
      assert_equal(nil, n.resolve('somename.html', 'fr'))
      assert_equal(nodes[:somename_en], n.resolve('somename.en.html', nil))
      assert_equal(nodes[:somename_en], n.resolve('somename.en.html', 'en'))
      assert_equal(nodes[:somename_en], n.resolve('somename.en.html', 'de'))
      assert_equal(nil, n.resolve('somename.fr.html', 'de'))

      assert_equal(nodes[:other], n.resolve('other.html', nil))
      assert_equal(nodes[:other], n.resolve('other.html', 'fr'))
      assert_equal(nodes[:other_en], n.resolve('other.html', 'en'))
      assert_equal(nodes[:other_en], n.resolve('other.en.html', nil))
      assert_equal(nodes[:other_en], n.resolve('other.en.html', 'de'))
      assert_equal(nil, n.resolve('other.fr.html', nil))
      assert_equal(nil, n.resolve('other.fr.html', 'en'))
    end

    assert_equal(nodes[:somename_en_frag], nodes[:somename_en].resolve('#othertest', 'de'))
    assert_equal(nodes[:somename_en_frag], nodes[:somename_en].resolve('#othertest', nil))
    assert_equal(nodes[:somename_en_fragnest], nodes[:somename_en].resolve('#nestedpath', nil))

    assert_equal(nil, nodes[:root].resolve('/somename.html#othertest', nil))
    assert_equal(nodes[:somename_en_frag], nodes[:root].resolve('/somename.html#othertest', 'en'))
    assert_equal(nodes[:somename_de_frag], nodes[:root].resolve('/somename.html#othertest', 'de'))
    assert_equal(nodes[:somename_en_frag], nodes[:root].resolve('/somename.en.html#othertest'))
    assert_equal(nodes[:somename_de_frag], nodes[:root].resolve('/somename.de.html#othertest'))

    assert_equal(nil, nodes[:dir2].resolve('index.html'))
    assert_equal(nodes[:dir2_index_en], nodes[:dir2].resolve('index.html', 'en'))

    assert_equal(nodes[:dir], nodes[:somename_en].resolve('/dir/'))
    assert_equal(nodes[:dir], nodes[:somename_en].resolve('/dir'))
    assert_equal(nodes[:root], nodes[:somename_en].resolve('/'))
  end

  def test_resolve_passive_nodes
    nodes = create_default_nodes

    assert_nil(nodes[:root].resolve('/images/webgen_logo.png'))

    shm = Webgen::SourceHandler::Main.new
    @website.config['passive_sources'] << ['/', "Webgen::Source::Resource", "webgen-passive-sources"]
    node = nodes[:root].resolve('/images/webgen_logo.png')
    assert_not_nil(node)
    assert_equal('/images/webgen_logo.png', node.alcn)
    assert_equal(['/images/', '/images/webgen_logo.png'].to_set, node.node_info[:used_meta_info_nodes])
  end

  def test_introspection
    node = Webgen::Node.new(@tree.dummy_root, '/', '/', {'lang' => 'de', :test => :value})
    assert(node.inspect =~ /alcn=\//)
  end

  def test_to_s
    node = Webgen::Node.new(@tree.dummy_root, '/', '/', {'lang' => 'de', :test => :value})
    assert_equal(node.alcn, node.to_s)
  end

  def test_changed
    node = Webgen::Node.new(@tree.dummy_root, 'test/', 'test', {'lang' => 'de', :test => :value})
    node.unflag(:dirty, :dirty_meta_info, :created)

    calls = 0
    @website.blackboard.add_listener(:node_changed?) {|n| assert(node, n); node.flag(:dirty); calls += 1}
    assert(node.changed?)
    assert_equal(1, calls)
    assert(node.changed?)
    assert_equal(1, calls)

    # Test :used_nodes array checking
    node.unflag(:dirty)
    node.node_info[:used_nodes] << node.alcn
    node.node_info[:used_nodes] << 'unknown alcn'
    node.node_info[:used_nodes] << @tree.dummy_root.alcn
    assert(node.changed?)
    assert_equal(1, calls)

    # Test :used_nodes array checking
    node.unflag(:dirty)
    node.node_info[:used_nodes] = Set.new
    node.node_info[:used_meta_info_nodes] << node.alcn
    assert(node.changed?)
    assert_equal(2, calls)
    node.unflag(:dirty)
    node.node_info[:used_meta_info_nodes] << 'unknown alcn'
    assert(node.changed?)
    assert_equal(2, calls)

    # Test circular depdendence
    other_node = Webgen::Node.new(@tree.dummy_root, '/other', 'test.l', {'lang' => 'de', :test => :value})
    other_node.flag(:dirty, :created)
    node.flag(:dirty)
    other_node.node_info[:used_nodes] = [node.alcn]
    node.node_info[:used_nodes] = [other_node.alcn]
    node.changed?
  end

  def test_user_nodes_changed?
    nodes = create_default_nodes

    assert(!nodes[:dir2_index_en].send(:user_nodes_changed?))
    nodes[:dir2_index_en]['used_nodes'] = '/some*.html'
    assert(nodes[:dir2_index_en].send(:user_nodes_changed?))
    nodes[:dir2_index_en]['used_nodes'] = '../some*.html'
    assert(nodes[:dir2_index_en].send(:user_nodes_changed?))
    nodes[:dir2_index_en]['used_nodes'] = '/someAA*.html'
    assert(!nodes[:dir2_index_en].send(:user_nodes_changed?))
    nodes[:dir2_index_en]['used_nodes'] = 'index.de.html'
    assert(nodes[:dir2_index_en].send(:user_nodes_changed?))
  end

  def test_meta_info_changed
    node = Webgen::Node.new(@tree.dummy_root, '/', '/')
    node.unflag(:dirty, :created)

    calls = 0
    @website.blackboard.add_listener(:node_meta_info_changed?) {|n| assert(node, n); node.flag(:dirty_meta_info); calls += 1}
    assert(node.meta_info_changed?)
    assert_equal(1, calls)
    assert(node.meta_info_changed?)
    assert_equal(1, calls)
  end

  def test_method_missing
    node = Webgen::Node.new(@tree.dummy_root, 'test/', 'test', {'lang' => 'de', :test => :value})
    assert_raise(NoMethodError) { node.unknown }
    obj = @website.cache.instance('Object')
    def obj.doit(node); :value; end
    node.node_info[:processor] = 'Object'
    assert_equal(:value, node.doit)
  end

  def test_matching
    root = Webgen::Node.new(@tree.dummy_root, '/', '/')
    node = Webgen::Node.new(root, 'somefile.de.html', 'somefile.html', {'lang' => 'de'})
    assert(node =~ '**/*')
    assert(node =~ '**/somefile.de.HTML')
    assert(node =~ '/**/somefile.*.html')
    assert(node !~ '/somefile.html')
    assert(node !~ '**/*.test')
  end

  def test_route_to
    nodes = create_default_nodes

    #arg is Node
    assert_equal('somename.en.html', nodes[:somename_en].route_to(nodes[:somename_en]))
    assert_equal('somename.de.html', nodes[:somename_en_frag].route_to(nodes[:somename_de]))
    assert_equal('file.html#frag', nodes[:dir].route_to(nodes[:dir_file_frag]))
    assert_equal('#frag', nodes[:dir_file].route_to(nodes[:dir_file_frag]))
    assert_equal('../dir2/index.html', nodes[:dir_file_frag].route_to(nodes[:dir2_index_en]))
    assert_equal('../dir2/index.html', nodes[:dir_file].route_to(nodes[:dir2_index_en]))

    assert_equal('./', nodes[:somename_en].route_to(nodes[:root]))
    assert_equal('../', nodes[:dir].route_to(nodes[:root]))
    assert_equal('dir/', nodes[:somename_en].route_to(nodes[:dir]))

    #arg is String
    assert_equal('somename.en.html', nodes[:somename_en].route_to('somename.en.html'))
    assert_equal('../other.html', nodes[:dir_file].route_to('/other.html'))
    assert_equal('../other', nodes[:dir_file].route_to('../other'))
    assert_equal('document/file2', nodes[:dir_file_frag].route_to('document/file2'))
    assert_equal('ftp://test', nodes[:dir].route_to('ftp://test'))

    #test args with '..' and '.': either too many of them or absolute path given
    assert_equal('../dir2', nodes[:dir_file].route_to('../../.././dir2'))
    assert_equal('../file', nodes[:dir_file].route_to('/dir/../file'))
    assert_equal('file', nodes[:dir_file].route_to('dir/../file'))

    #arg is something else
    assert_raise(ArgumentError) { nodes[:root].route_to(5) }
  end

  def test_routing_node
    nodes = create_default_nodes

    assert_equal(nodes[:somename_en], nodes[:somename_en].routing_node('en'))

    assert_equal(nodes[:dir], nodes[:dir].routing_node('en'))
    assert_equal(nodes[:dir2_index_en], nodes[:dir2].routing_node('en'))
    assert_equal(nodes[:dir2_index_en], nodes[:dir2].routing_node('en'))
    @website.cache.volatile.clear
    nodes[:dir2].meta_info['index_path'] = 'unknown'
    assert_equal(nodes[:dir2], nodes[:dir2].routing_node('en'))
  end

  def test_comparision_op
    nodes = create_default_nodes
    nodes[:somename_en]['title'] = 'somename'
    nodes[:other_en]['title'] = 'other'

    assert_equal(0, nodes[:somename_en] <=> nodes[:somename_en])
    assert_equal(1, nodes[:somename_en] <=> nodes[:other_en])
    assert_equal(-1, nodes[:other_en] <=> nodes[:somename_en])
    nodes[:other_en]['sort_info'] = 1
    assert_equal(1, nodes[:somename_en] <=> nodes[:other_en])
    nodes[:other_en]['sort_info'] = '2008-06-28'
    nodes[:somename_en]['sort_info'] = '2008-06-29'
    assert_equal(1, nodes[:somename_en] <=> nodes[:other_en])
  end

  def test_level
    nodes = create_default_nodes
    assert_equal(0, nodes[:root].level)
    assert_equal(1, nodes[:dir].level)
    assert_equal(2, nodes[:dir_file].level)
    assert_equal(3, nodes[:dir_file_frag].level)
  end

  def test_in_subtree_of
    nodes = create_default_nodes

    assert(nodes[:somename_en].in_subtree_of?(nodes[:root]))
    assert(nodes[:dir].in_subtree_of?(nodes[:root]))

    assert(nodes[:dir_file].in_subtree_of?(nodes[:dir]))

    assert(nodes[:dir_file_frag].in_subtree_of?(nodes[:root]))
    assert(nodes[:dir_file_frag].in_subtree_of?(nodes[:dir]))
    assert(nodes[:dir_file_frag].in_subtree_of?(nodes[:dir_file]))

    assert(!nodes[:dir2_index_en].in_subtree_of?(nodes[:dir]))
    assert(!nodes[:somename_en].in_subtree_of?(nodes[:dir]))
    assert(!nodes[:somename_en].in_subtree_of?(nodes[:dir_file]))
    assert(!nodes[:dir_file].in_subtree_of?(nodes[:dir2_index_en]))
  end

  def test_link_to
    nodes = create_default_nodes

    # general tests
    assert_equal('<a href="#frag">frag</a>',
                 nodes[:somename_en].link_to(nodes[:somename_en_frag]))
    assert_equal('<a href="#frag">link_text</a>',
                 nodes[:somename_en].link_to(nodes[:somename_en_frag], :link_text => 'link_text'))
    assert_equal('<a attr1="val1" href="#frag">frag</a>',
                 nodes[:somename_en].link_to(nodes[:somename_en_frag], 'attr1' => 'val1'))
    assert_equal('<a href="#frag">frag</a>',
                 nodes[:somename_en].link_to(nodes[:somename_en_frag], :attr1 => 'val1'))
    assert_equal('<a href="dir2/index.html">index en</a>',
                 nodes[:somename_en].link_to(nodes[:dir2_index_en]))

    nodes[:somename_en_frag]['link_attrs'] = {:link_text => 'Default Text', 'class'=>'help'}
    assert_equal('<a attr1="val1" class="help" href="#frag">link_text</a>',
                 nodes[:somename_en].link_to(nodes[:somename_en_frag], :link_text => 'link_text', 'attr1' => 'val1'))

    # links to directories
    assert_equal('<a href="dir2/index.de.html">routed_de</a>',
                 nodes[:somename_de].link_to(nodes[:dir2]))
    assert_equal('<a href="dir2/index.html">routed</a>',
                 nodes[:somename_en].link_to(nodes[:dir2]))
    assert_equal('<a href="dir2/index.de.html">routed_de</a>',
                 nodes[:somename_en].link_to(nodes[:dir2], :lang => 'de'))
    assert_equal('<span>routed</span>',
                 nodes[:dir2_index_en].link_to(nodes[:dir2]))

    # varying the website.link_to_current_page option
    @website.config['website.link_to_current_page'] = true
    assert_equal('<a class="help" href="#frag">Default Text</a>',
                 nodes[:somename_en_frag].link_to(nodes[:somename_en_frag]))
    @website.config['website.link_to_current_page'] = false
    assert_equal('<span class="help">Default Text</span>',
                 nodes[:somename_en_frag].link_to(nodes[:somename_en_frag]))
  end

  def test_url
    assert_equal("webgen://webgen.localhost/hallo", Webgen::Node.url("hallo").to_s)
    assert_equal("webgen://webgen.localhost/hallo%20du", Webgen::Node.url("hallo du").to_s)
    assert_equal("webgen://webgen.localhost/hall%C3%B6chen", Webgen::Node.url("hallöchen").to_s)
    assert_equal("webgen://webgen.localhost/hallo#du", Webgen::Node.url("hallo#du").to_s)

    assert_equal("webgen://webgen.localhost/test", Webgen::Node.url("/test").to_s)
    assert_equal("http://example.com/test", Webgen::Node.url("http://example.com/test").to_s)

    assert_equal("test", Webgen::Node.url("test", false).to_s)
    assert_equal("http://example.com/test", Webgen::Node.url("http://example.com/test", false).to_s)
  end

  def test_find
    nodes = create_default_nodes

    check = lambda do |correct, result|
      assert_equal(correct.collect {|n| nodes[n].alcn }, result.to_list.flatten)
    end

    check.call([:somename_en, :somename_en_frag, :somename_en_fragnest, :somename_de, :somename_de_frag,
                :other, :other_en, :dir, :dir_file, :dir_file_frag, :dir2, :dir2_index_en, :dir2_index_de],
               nodes[:root].find())

    # :levels
    check.call([],
               nodes[:root].find(:levels => 0))
    check.call([:somename_en, :somename_de, :other, :other_en, :dir, :dir2],
               nodes[:root].find(:levels => 1))

    # :alcn
    check.call([:somename_en, :somename_en_frag, :somename_en_fragnest, :somename_de, :somename_de_frag,
                :other, :other_en, :dir, :dir2],
               nodes[:root].find(:alcn => '*'))
    check.call([:somename_en, :somename_de, :other, :other_en, :dir, :dir2],
               nodes[:root].find(:alcn => '*', :levels => 1))
    check.call([:somename_en, :other_en],
               nodes[:root].find(:alcn => '/*.en.html'))

    # :sort
    check.call([:somename_en, :somename_en_frag, :somename_en_fragnest, :somename_de, :somename_de_frag,
                :other, :other_en, :dir, :dir_file, :dir_file_frag, :dir2, :dir2_index_en, :dir2_index_de],
               nodes[:root].find(:sort => false))
    check.call([:dir, :dir_file, :dir_file_frag, :dir2, :dir2_index_en, :dir2_index_de, :other, :other_en,
                :somename_de, :somename_de_frag, :somename_en, :somename_en_frag, :somename_en_fragnest],
               nodes[:root].find(:sort => true))
    check.call([:somename_en, :somename_en_frag, :somename_en_fragnest, :dir, :dir_file, :dir_file_frag, :dir2, :dir2_index_en, :dir2_index_de,
                :somename_de, :somename_de_frag, :other_en, :other],
               nodes[:root].find(:sort => 'sort_test'))

    # :limit
    check.call([:somename_en, :somename_en_frag, :somename_en_fragnest, :somename_de, :somename_de_frag],
               nodes[:root].find(:limit => 5))
    check.call([:somename_en, :somename_en_frag, :somename_en_fragnest, :somename_de, :somename_de_frag,
                :other, :other_en, :dir, :dir_file, :dir_file_frag, :dir2, :dir2_index_en, :dir2_index_de],
               nodes[:root].find(:limit => 100))
    check.call([:somename_en, :somename_en_frag, :somename_en_fragnest, :somename_de, :somename_de_frag,
                :other, :other_en, :dir, :dir_file, :dir_file_frag, :dir2, :dir2_index_en, :dir2_index_de],
               nodes[:root].find(:limit => 'hallo'))

    # :offset
    check.call([:somename_en, :somename_en_frag, :somename_en_fragnest, :somename_de, :somename_de_frag,
                :other, :other_en, :dir, :dir_file, :dir_file_frag, :dir2, :dir2_index_en, :dir2_index_de],
               nodes[:root].find(:offset => 0))
    check.call([:other, :other_en, :dir, :dir_file, :dir_file_frag, :dir2, :dir2_index_en, :dir2_index_de],
               nodes[:root].find(:offset => 5))
    check.call([:somename_en, :somename_en_frag, :somename_en_fragnest, :somename_de, :somename_de_frag,
                :other, :other_en, :dir, :dir_file, :dir_file_frag, :dir2, :dir2_index_en, :dir2_index_de],
               nodes[:root].find(:offset => 'hallo'))

  end

end
