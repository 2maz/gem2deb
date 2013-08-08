# Copyright © 2011, Antonio Terceiro <terceiro@softwarelivre.org>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require 'gem2deb'
require 'yaml'
require 'rubygems/ext'
require 'gem2deb/metadata'
require 'fileutils'

module Gem2Deb
  class ExtensionBuilder

    include Gem2Deb

    attr_reader :extension
    attr_reader :directory

    def initialize(extension)
      @extension = extension
      @directory = File.dirname(extension)
    end

    def clean
      Dir.chdir(directory) do
        if File.exists?('Makefile')
          run 'make clean'
        end
      end
    end

    def build_and_install(destdir)
      clean
      results = []
      rubygems_builder =
        case extension
        when /extconf/ then
          Gem::Ext::ExtConfBuilder
        when /configure/ then
          Gem::Ext::ConfigureBuilder
        when /rakefile/i, /mkrf_conf/i then
          Gem::Ext::RakeBuilder
        else
          puts "Cannot build extension '#{extension}'"
          exit(1)
        end
      begin
        target = File.expand_path(File.join(destdir, RbConfig::CONFIG['vendorarchdir']))
        FileUtils.mkdir_p(File.dirname(target))
        Dir.chdir(directory) do
          rubygems_builder.build(extension, '.', target, results)
          puts results
        end
      rescue Exception => e
        puts results
        raise e
      end
    end

    def self.build_all_extensions(root, destdir)
      all_extensions(root).each do |extension|
        ext = new(extension)
        ext.clean
        ext.build_and_install(destdir)
      end
    end

    def self.all_extensions(root)
      @metadata ||= Gem2Deb::Metadata.new(root)
      @metadata.native_extensions
    end
  end
end

if $PROGRAM_NAME == __FILE__
  if ARGV.length == 2
    Gem2Deb::ExtensionBuilder.build_all_extensions(*ARGV)
  else
    puts "usage: #{File.basename($PROGRAM_NAME)} ROOT DESTDIR"
    exit(1)
  end
end
