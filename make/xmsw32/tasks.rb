module Make
  include FileUtils

  def copy_files_to_dist
    puts "copy_files_to_dist dir=#{pwd}"
    if ENV['APP']
      if APP['clone']
        sh APP['clone'].gsub(/^git /, "#{GIT} --git-dir=#{ENV['APP']}/.git ")
      else
        cp_r ENV['APP'], "#{TGT_DIR}/app"
      end
      if APP['ignore']
        APP['ignore'].each do |nn|
          rm_rf "dist/app/#{nn}"
        end
      end
    end

    cp_r "fonts", "#{TGT_DIR}/fonts"
    cp   "lib/shoes.rb", "#{TGT_DIR}/lib"
    cp_r "lib/shoes", "#{TGT_DIR}/lib"
    cp_r "lib/exerb", "#{TGT_DIR}/lib"
    cp_r "samples", "#{TGT_DIR}/samples"
    cp_r "static", "#{TGT_DIR}/static"
    cp   "README.md", "#{TGT_DIR}/README.txt"
    cp   "CHANGELOG", "#{TGT_DIR}/CHANGELOG.txt"
    cp   "COPYING", "#{TGT_DIR}/COPYING.txt"
  end

  def cc(t)
    sh "#{CC} -I. -c -o#{t.name} #{LINUX_CFLAGS} #{t.source}"
  end

  # Subs in special variables
  def rewrite before, after, reg = /\#\{(\w+)\}/, reg2 = '\1'
    File.open(after, 'w') do |a|
      File.open(before) do |b|
        b.each do |line|
          a << line.gsub(reg) do
            if reg2.include? '\1'
              reg2.gsub(%r!\\1!, Object.const_get($1))
            else
              reg2
            end
          end
        end
      end
    end
  end

  def copy_files glob, dir
    FileList[glob].each { |f| cp_r f, dir }
  end

  #  Windows cross compile.  Copy the ruby libs
  #  Then copy the deps.
  def pre_build
    puts "pre_build dir=#{`pwd`}"
    mkdir_p "#{TGT_DIR}/lib"
    cp_r "#{EXT_RUBY}/lib/ruby", "#{TGT_DIR}/lib"
    SOLOCS.each_value do |path|
      cp "#{path}", "#{TGT_DIR}"
    end
    # do some windows things
    sh "#{WINDRES} -I. shoes/appwin32.rc shoes/appwin32.o"
 end

  # common_build is a misnomer. Builds extentions, gems
  def common_build
    puts "common_build dir=#{pwd} #{SHOES_TGT_ARCH}"
    #mkdir_p "#{TGT_DIR}/ruby"
    #cp_r  "#{EXT_RUBY}/lib/ruby/#{RUBY_V}", "#{TGT_DIR}/ruby/lib"
    %w[req/ftsearch/lib/* req/rake/lib/*].each do |rdir|
      FileList[rdir].each { |rlib| cp_r rlib, "#{TGT_DIR}/lib/ruby/#{TGT_RUBY_V}" }
    end
    %w[req/ftsearch/ext/ftsearchrt req/chipmunk/ext/chipmunk].
    #%w[req/binject/ext/binject_c req/ftsearch/ext/ftsearchrt req/bloopsaphone/ext/bloops req/chipmunk/ext/chipmunk].
      each { |xdir| copy_ext xdir, "#{TGT_DIR}/lib/ruby/#{TGT_RUBY_V}/#{SHOES_TGT_ARCH}" }

    gdir = "#{TGT_DIR}/lib/ruby/gems/#{RUBY_V}"
    {}.each do |gemn, xdir|
    #{'hpricot' => 'lib', 'json' => 'lib/json/ext', 'sqlite3' => 'lib'}.each do |gemn, xdir|
      spec = eval(File.read("req/#{gemn}/gemspec"))
      mkdir_p "#{gdir}/specifications"
      mkdir_p "#{gdir}/gems/#{spec.full_name}/lib"
      FileList["req/#{gemn}/lib/*"].each { |rlib| cp_r rlib, "#{gdir}/gems/#{spec.full_name}/lib" }
      mkdir_p "#{gdir}/gems/#{spec.full_name}/#{xdir}"
      FileList["req/#{gemn}/ext/*"].each { |elib| copy_ext elib, "#{gdir}/gems/#{spec.full_name}/#{xdir}" }
      cp "req/#{gemn}/gemspec", "#{gdir}/specifications/#{spec.full_name}.gemspec"
    end
  end

  # Check the environment
  def env(x)
    unless ENV[x]
      abort "Your #{x} environment variable is not set!"
    end
    ENV[x]
  end
end


include FileUtils

class MakeLinux
  extend Make

  class << self
    def copy_ext xdir, libdir
      Dir.chdir(xdir) do
        unless system "ruby", "extconf.rb" and system "make"
          raise "Extension build failed"
        end
      end
      copy_files "#{xdir}/*.so", libdir
    end

    # FIXME - depends on setting in env.rb - should be a setting in
    # crosscompile file written by :linux:setup:xxxx but it isn't.
    def find_and_copy thelib, newplace
      tp = "#{TGT_SYS_DIR}usr/lib/#{thelib}"
      if File.exists? tp
        cp tp, newplace
      else
        puts "Can't find library #{tp}"
      end
    end

    def copy_deps_to_dist
      puts "copy_deps_to_dist dir=#{pwd}"
      #pre_build task copied this
      #cp    "#{::EXT_RUBY}/lib/lib#{::RUBY_SO}.so", "dist/lib#{::RUBY_SO}.so"
      #ln_s  "lib#{::RUBY_SO}.so", "#{TGT_DIR}/lib#{::RUBY_SO}.so.#{::RUBY_V[/^\d+\.\d+/]}"
      #find_and_copy "libportaudio.so", "#{TGT_DIR}/libportaudio.so.2"
      #find_and_copy  "libsqlite3.so", "#{TGT_DIR}/libsqlite3.so.0"
      unless ENV['GDB']
        sh    "strip -x #{TGT_DIR}/*.so.*"
        sh    "strip -x #{TGT_DIR}/*.so"
      end
    end

    def setup_system_resources
      cp APP['icons']['gtk'], "#{TGT_DIR}/static/app-icon.png"
    end
 
    # name {TGT_DIR}/shoes
    def make_app(name)
      puts "make_app dir=#{pwd} arg=#{name}"
      bin = "#{name}.exe"
      rm_f name
      rm_f bin
      sh "#{CC} -o #{bin} bin/main.o shoes/appwin32.o -L#{TGT_DIR} -mwindows -lshoes #{LINUX_LIBS}"
    end

    def make_so(name)
      puts "make_so dir=#{pwd} arg=#{name}"
      #ldflags = LINUX_LDFLAGS.sub! /INSTALL_NAME/, "-install_name @executable_path/lib#{SONAME}.#{DLEXT}"
      sh "#{CC} -o #{name} #{OBJ.join(' ')} #{LINUX_LDFLAGS} #{LINUX_LIBS}"
    end

    #  Does nothing for Windows
    def make_userinstall    
    end
    
    def make_resource(t)
      puts "make resource"
    end

    
    def make_installer
      # assumes you have NSIS installed on your box in the system PATH
      # def sh(*args); super; end
      puts "make_installer #{`pwd`}"
      mkdir_p "pkg"
      rm_rf "#{TGT_DIR}/nsis"
      cp_r  "platform/msw", "#{TGT_DIR}/nsis"
      cp APP['icons']['win32'], "#{TGT_DIR}/nsis/setup.ico"
      rewrite "#{TGT_DIR}/nsis/base.nsi", "#{TGT_DIR}/nsis/#{WINFNAME}.nsi"
      Dir.chdir("#{TGT_DIR}/nsis") do
        #sh "\"#{env('NSIS')}\\makensis.exe\" #{NAME}.nsi"
        sh "makensis #{WINFNAME}.nsi"
      end
      mv "#{TGT_DIR}/nsis/#{WINFNAME}.exe", "pkg"
    end

  end
end
