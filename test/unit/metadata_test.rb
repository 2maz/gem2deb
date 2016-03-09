require_relative '../test_helper'
require 'gem2deb/metadata'
require 'yaml'

class MetaDataTest < Gem2DebTestCase

  {
    'simpleextension'         => true,
    'simpleextension_in_root' => true,
    'simplegem'               => false,
    'simplemixed'             => true,
    'simpleprogram'           => false,
    'simpletgz'               => false,
  }.each do |source_package, has_extensions|
    should "correctly detect native extensions for #{source_package}" do
      assert_equal has_extensions, Gem2Deb::Metadata.new(File.join('test/sample', source_package)).has_native_extensions?
    end
  end

  def setup
    FileUtils.mkdir_p('test/tmp')
  end

  def teardown
    FileUtils.rmdir('test/tmp')
  end

  context 'without gemspec' do
    setup do
      @metadata = Gem2Deb::Metadata.new('test/tmp')
    end
    should 'have no homepage' do
      assert_nil @metadata.homepage
    end
    should 'have no short description' do
      assert_nil @metadata.short_description
    end
    should 'have no long description' do
      assert_nil @metadata.long_description
    end
    should 'have no dependencies' do
      assert_equal [], @metadata.dependencies
    end
    should 'have no test files' do
      assert_equal [], @metadata.test_files
    end
    should 'provide a gem name from source dir' do
      assert_equal 'tmp', @metadata.name
    end
    should 'provide a fallback version number' do
      assert_not_nil @metadata.version
    end
    should 'read version number from source dir name when available' do
      @metadata.stubs(:source_dir).returns('/tmp/package-1.2.3')
      assert_equal 'package', @metadata.name
      assert_equal '1.2.3', @metadata.version
    end
    should 'use bin/ as bindir' do
      assert_equal 'bin', @metadata.bindir
    end
    should 'use all programs under bin/' do
      Dir.stubs(:glob).with('test/tmp/bin/*').returns(['test/tmp/bin/foo'])
      assert_equal ['foo'], @metadata.executables
    end
  end

  context 'with gemspec' do
    setup do
      @gemspec = mock
      @metadata = Gem2Deb::Metadata.new('test/tmp')
      @metadata.stubs(:gemspec).returns(@gemspec)
    end

    should 'obtain gem name from gemspec' do
      @gemspec.stubs(:name).returns('weird')
      assert_equal 'weird', @metadata.name
    end

    should 'obtain gem version from gemspec' do
      @gemspec.stubs(:version).returns(Gem::Version.new('0.0.1'))
      assert_equal '0.0.1', @metadata.version
    end

    should 'obtain homepage from gemspec' do
      @gemspec.stubs(:homepage).returns('http://www.debian.org/')
      assert_equal 'http://www.debian.org/', @metadata.homepage
    end

    should 'obtain short description from gemspec' do
      @gemspec.stubs(:summary).returns('This library does stuff')
      assert_equal 'This library does stuff', @metadata.short_description
    end

    should 'obtain long detect from gemspec' do
      @gemspec.stubs(:description).returns('This is the long description, bla bla bla')
      assert_equal 'This is the long description, bla bla bla', @metadata.long_description
    end

    should 'obtain dependencies list from gemspec' do
      @gemspec.stubs(:dependencies).returns(['gem1', 'gem2'])
      assert_equal ['gem1', 'gem2'], @metadata.dependencies
    end

    should 'obtain test files list from gemspec' do
      @gemspec.stubs(:test_files).returns(['test/class1_test.rb', 'test/class2_test.rb', 'test/not_a_test.txt'])
      assert_equal ['test/class1_test.rb', 'test/class2_test.rb'], @metadata.test_files
    end

    should 'use whatever directory gemspec says as bindir' do
      @gemspec.stubs(:bindir).returns('programs')
      assert_equal 'programs', @metadata.bindir
    end

    should 'resist bindir being false' do
      @gemspec.stubs(:bindir).returns(false)
      assert_equal 'bin', @metadata.bindir
    end

    should 'use whatever programs the gemspec says' do
      @gemspec.stubs(:executables).returns(%w(foo bar))
      assert_equal ['foo', 'bar'], @metadata.executables
    end

    should 'not use an empty executables list' do
      @gemspec.stubs(:executables).returns([])
      assert_equal nil, @metadata.executables
    end

  end

  context 'on multi-binary source packages' do

    setup do
      Dir.chdir('test/sample/multibinary') do
        @metadata = Gem2Deb::Metadata.new('baz')
      end
    end

    should 'get the right path for extensions without a gemspec' do
      assert_equal ['baz/ext/baz/extconf.rb'], @metadata.native_extensions
    end

    should 'get the right path to extensions with a gemspec' do
      @gemspec = mock
      @metadata.stubs(:gemspec).returns(@gemspec)
      @gemspec.expects(:extensions).returns(['path/to/extconf.rb'])
      assert_equal ['baz/path/to/extconf.rb'], @metadata.native_extensions
    end

  end

  context 'timestamps' do
    should 'use date from changelog if available' do
      Dir.chdir('test/sample/install_as_gem') do
        @metadata = Gem2Deb::Metadata.new('.')
      end
      # the gemspec only stores the date and zeroes the hour
      assert_equal Time.parse('2015-11-20 00:00:00 UTC'), @metadata.gemspec.date
    end
  end

  context 'filelists' do
    should 'should always be sorted' do
      @metadata = Gem2Deb::Metadata.new('test/sample/unsorted_names')
      correctly_sorted = ['lib/file1.rb', 'lib/file2.rb']
      assert_equal correctly_sorted, @metadata.gemspec.test_files.select { |f| f.include? 'lib/file' }
      assert_equal correctly_sorted, @metadata.gemspec.files.select { |f| f.include? 'lib/file' }
    end
  end

  context 'when upstream abuses git in gemspecs' do

    should 'workaround git usage' do
      # create
      dir = File.join(tmpdir, 'gitabuser')
      FileUtils.mkdir_p(dir)
      Dir.chdir dir do
        run_command 'git init'
        File.open('gitabuser.gemspec', 'w') do |f|
          f.puts($GIT_ABUSER_GEMSPEC)
        end
        FileUtils.mkdir 'lib'
        File.open('lib/gitabuser.rb', 'w') do |f|
          f.puts 'module GitAbuser; end'
        end
        run_command 'git add .'
        run_command 'git commit -m "there you go"'
      end

      @metadata = self.class.silently { Gem2Deb::Metadata.new(dir) }
      assert_not_nil @metadata.gemspec
      assert_equal ['gitabuser.gemspec', 'lib/gitabuser.rb'], @metadata.gemspec.files
    end

  end

end

$GIT_ABUSER_GEMSPEC = <<EOF
Gem::Specification.new do |s|
  s.name        = "gitabuser"
  s.version     = "1"
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Antonio Terceiro"]
  s.email       = ["terceiro@debian.org"]
  s.homepage    = ""
  s.summary     = %q{Sample gem that }
  s.description = %q{This gem is used to test the case where dh-make-ruby is called on a directory}

  s.rubyforge_project = "simplegit"
  s.files             = `/unexisting/git ls-files`.split
  s.executables       = `/unexisting/git ls-files`.split.select { |f| File.executable?(f) }
  s.test_files        = `/unexisting/git ls-files`.split.select { |f| f =~ /^(test|spec|features)/ }
  s.require_paths     = ["lib"]
end
EOF
