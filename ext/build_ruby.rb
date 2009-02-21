
# Extension abuse in order to build our patched binary as part of the gem install process.

if RUBY_PLATFORM =~ /win32|windows/
  raise "Windows is not supported."
end

unless RUBY_VERSION == '1.8.6'
  raise "Wrong Ruby version, you're at '#{RUBY_VERSION}', need 1.8.6"
end

source_dir = File.expand_path(File.dirname(__FILE__)) + "/../ruby"
tmp = "/tmp/"

require 'fileutils'
require 'rbconfig'

def execute(command)    
  puts command
  unless system(command)
    puts "Failed: #{command.inspect}"
    exit -1 
  end
end

def which(basename)
  # execute('which') is not compatible across Linux and BSD
  ENV['PATH'].split(File::PATH_SEPARATOR).detect do |directory|
    path = File.join(directory, basename.to_s)
    path if File.exist? path
  end
end

if which('ruby-bleak-house') and
  (patchlevel  = `ruby-bleak-house -e "puts RUBY_PATCHLEVEL"`.to_i) >= 903
  puts "** Binary `ruby-bleak-house` is already available (patchlevel #{patchlevel})"
else
  # Build
  Dir.chdir(tmp) do
    build_dir = "bleak_house"

    FileUtils.rm_rf(build_dir) rescue nil
    if File.exist? build_dir
      raise "Could not delete previous build dir #{Dir.pwd}/#{build_dir}"
    end

    Dir.mkdir(build_dir)

    begin
      Dir.chdir(build_dir) do

        puts "** Copy Ruby source"
        bz2 = "ruby-1.8.6-p286.tar.bz2"
        FileUtils.copy "#{source_dir}/#{bz2}", bz2

        puts "** Extract"
        execute("tar xjf #{bz2}")
        File.delete bz2

        Dir.chdir("ruby-1.8.6-p286") do

          puts "** Patch"
          execute("patch -p0 < '#{source_dir}/ruby.patch'")

          puts "** Configure"
          execute("./configure #{Config::CONFIG['configure_args']}")
          
          env = Config::CONFIG.map do |key, value|
            "#{key}=#{value.inspect}" if key.upcase == key and value
          end.compact.join(" ")            

          puts "** Make"
          execute("env #{env} make")

          binary = "#{Config::CONFIG['bindir']}/ruby-bleak-house"

          puts "** Install binary"
          if File.exist? "ruby"
            # Avoid "Text file busy" error
            File.delete binary if File.exist? binary
            exec("cp ./ruby #{binary}; chmod 755 #{binary}")
          else
            raise
          end
        end

      end
    end

    puts "Success"
  end

end
