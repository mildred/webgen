# -*- encoding: utf-8 -*-

require 'mail'

module Webgen::Extension

  class MailDirSource

    include Webgen::Extension::Base
    attr_reader :maildir
    attr_reader :outtmpl
    
    def outdir
      File.dirname(outtmpl)
    end

    def execute
      basedir = website.directory
      @maildir = File.expand_path(File.join(website.directory, config['from']))
      @outtmpl = File.expand_path(File.join(website.directory, config['to']))
      return unless File.directory? maildir
      throw Exception unless File.directory? outdir
      mail_files.each do |mail_file|
        mail = Mail.read mail_file
        title = mail.subject.tr("A-Z", "a-z").gsub(/[^a-z0-9_-]+/, '_').gsub(/^_*/, "").gsub(/_*$/, "")
        filename = mail.date.strftime(outtmpl) % [title]
        # TODO: if the file already exists, check that it has the same mesage-id
        # TODO: else, reply saying the message could not be processed.
        next if File.exist? filename
        meta = {
          'title'      => mail.subject,
          'created_at' => mail.date,
          'kind'       => 'article',
          'publish'    => true,
          'message_id' => mail.message_id}

        # Find out meta information and body
        meta.merge! meta_author(mail['from'].decoded)
        body = mail_body(mail)
        body = body_meta(body) do |head|
          meta.merge! head
        end

        # Write File
        body = "---\n" + body unless body.start_with? "--- " or body.start_with? "---\n"
        template = YAML::dump(meta) + body
        write_file(filename, template)
      end
    end

    def mail_files
      Dir.chdir(maildir) do
        Dir["./{new,cur}/*"].delete_if { |f| f == '.' or f == '..' }.map { |f| File.expand_path(f) }
      end
    end

    def meta_author(from)
      m = from.match /^(.*)\s+<(.*)>$/
      meta = {}
      if m then
        meta['author'] = m[1]
        meta['author_email'] = m[2]
      else
        meta['author'] = from
      end
      return meta
    end

    def mail_body(mail)
      if mail.multipart? then
        message_parts = mail.parts.select { |p| p.class == Mail::Part }
        body = message_parts.select{ |p| p.content_type =~ /^text\/plain/ }.map { |p| p.body.decoded }.join '\n'
      else
        body = mail.body.decoded
      end
      body.lstrip
    end
    
    def body_meta(body, &block)
      if body.start_with? "---\n"
        begin
          head = YAML::load(body)
        rescue
        else
          block.call(head)
          m = body[4..-1].match(/^---(\s+.*)?$/)
          body = if m then body[4+m.begin(0)..-1] else "" end
        end
      end
      body
    end

    def write_file(path, content)
      dir  = File.dirname(path)
      file = File.basename(path)
      Dir.chdir(dir) do
        File.open(file, 'w') { |fh| fh.write(content) }
        system "git", "add", "--", file
      end
    end
  end

end


