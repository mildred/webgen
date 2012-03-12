# -*- encoding: utf-8 -*-

module Webgen

  # Namespace for all extensions.

  module Extension

    autoload :Base,          'webgen/extensions/base'
    autoload :PreExec,       'webgen/extensions/pre_exec'
    autoload :MailDirSource, 'webgen/extensions/maildirsource'

  end

end
