require 'fileutils'
require 'pathname'
require 'pliny/version'
require 'uri'

module Pliny::Commands
  class Updater
    attr_accessor :args, :opts, :stream

    def self.run(args, opts = {}, stream = $stdout)
      new(args, opts, stream).run!
    end

    def initialize(args = {}, opts = {}, stream = $stdout)
      @args = args
      @opts = opts
      @stream = stream
    end

    def run!
      abort("Pliny app not found") unless File.exist?("Gemfile")

      version_current = get_current_version
      version_target  = Gem::Version.new(Pliny::VERSION)

      if version_current == version_target
        display "Version #{version_current} is current, nothing to update."
      elsif version_current > version_target
        display "pliny-update is outdated. Please update it with `gem install pliny` or similar."
      else
        display "Updating from #{version_current} to #{version_target}..."
        ensure_repo_available
        save_patch(version_current, version_target)
        exec "patch -p1 < #{patch_file}"
      end
    end

    protected

    # we need a local copy of the pliny repo to produce a diff
    def ensure_repo_available
      unless File.exists?(repo_dir)
        system("git clone git@github.com:interagent/pliny.git #{repo_dir}")
      else
        system("cd #{repo_dir} && git fetch")
      end
    end

    def get_current_version
      path = `bundle show pliny`
      file = File.basename(path)
      Gem::Version.new(file.sub("pliny-", ""))
    end

    def save_patch(curr, target)
      # take a diff from the template folder from diff
      diff = `cd #{repo_dir} && git diff v#{curr}..v#{target} lib/template/`

      # take lib/template away from the path name so we can apply
      diff.gsub!(/^(\-\-\-|\+\+\+) (\w)\/lib\/template/, '\1 \2')

      # save it
      File.open(patch_file, "w") { |f| f.puts diff }
    end

    def display(msg)
      stream.puts msg
    end

    def repo_dir
      File.join(Dir.home, ".tmp/pliny-repo")
    end

    def patch_file
      File.join(repo_dir, "pliny-update.patch")
    end
  end
end
