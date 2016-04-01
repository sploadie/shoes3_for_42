include FileUtils
cf =(ENV['ENV_CUSTOM'] || "#{TGT_ARCH}-custom.yaml")
if File.exists? cf
  custmz = YAML.load_file(cf)
  BREWLOC = custmz['Deps']
  ZLIBLOC = custmz['Zlib']
  EXT_RUBY = custmz['Ruby'] ? custmz['Ruby'] : RbConfig::CONFIG['prefix']
  ENV['GDB'] = 'basic' if custmz['Debug'] == true
  ENV['CDEFS'] = custmz['CFLAGS'] if custmz['CFLAGS']
  APP['GEMLOC'] = custmz['Gemloc'] if custmz['Gemloc']
  APP['EXTLOC'] = custmz['Extloc'] if custmz['Extloc']
  APP['EXTLIST'] = custmz['Exts'] if custmz['Exts']
  APP['GEMLIST'] = custmz['Gems'] if custmz['Gems']
  ENV['CDEFS'] = custmz['CFLAGS'] if custmz['CFLAGS']
  APP['INCLGEMS'] = custmz['InclGems'] if custmz['InclGems']
else
  EXT_RUBY = RbConfig::CONFIG['prefix']
  BREWLOC = "/usr/local"
  ZLIBLOC = "/usr/local/opt/zlib/lib"
  ENV['DEBUG'] = "yes"
  ENV['CDEFS'] = '-DNEW_RADIO'
end
# use the platform Ruby claims
# require 'rbconfig' not needed
SHOES_GEM_ARCH = "#{Gem::Platform.local}"

CC = ENV['CC'] ? ENV['CC'] : "gcc"
file_list =  %w{shoes/console/tesi.c shoes/console/cocoa-term.m shoes/native/cocoa.m shoes/http/nsurl.m} + ["shoes/*.c"]

SRC = FileList[*file_list]
OBJ = SRC.map do |x|
  x.gsub(/\.\w+$/, '.o')
end

ADD_DLL = []

# Darwin build environment
=begin
pkg_config = `which pkg-config` != ""
pkgs = `pkg-config --list-all`.split("\n").map {|p| p.split.first} unless not pkg_config
if pkg_config and pkgs.include?("cairo") and pkgs.include?("pango")
  CAIRO_CFLAGS = ENV['CAIRO_CFLAGS'] || `pkg-config --cflags cairo`.strip
  CAIRO_LIB = ENV['CAIRO_LIB'] ? "-L#{ENV['CAIRO_LIB']}" : `pkg-config --libs cairo`.strip
  PANGO_CFLAGS = ENV['PANGO_CFLAGS'] || `pkg-config --cflags pango`.strip
  PANGO_LIB = ENV['PANGO_LIB'] ? "-L#{ENV['PANGO_LIB']}" : `pkg-config --libs pango`.strip
else
  # Hack for when pkg-config is not yet installed
  CAIRO_CFLAGS, CAIRO_LIB, PANGO_CFLAGS, PANGO_LIB = "", "", "", ""
=end
CAIRO_CFLAGS = `pkg-config --cflags cairo`.strip
CAIRO_LIB = `pkg-config --libs cairo`.strip
PANGO_CFLAGS = `pkg-config --cflags pango`.strip
PANGO_LIB = `pkg-config --libs pango`.strip
RSVG_CFLAGS = `pkg-config --cflags librsvg-2.0`.strip
RSVG_LIB = `pkg-config --libs librsvg-2.0`.strip
ADDITIONAL_CFLAGS = "-I/nfs/2014/t/tgauvrit/.brew/Cellar/librsvg/2.40.13/include/librsvg-2.0/librsvg -I/nfs/2014/t/tgauvrit/.brew/Cellar/jpeg/8d/include -I/nfs/2014/t/tgauvrit/.brew/Cellar/giflib/4.2.3/include"

png_lib = 'png'

LINUX_CFLAGS = %[-g -Wall  -I#{BREWLOC}/include #{CAIRO_CFLAGS} #{PANGO_CFLAGS} #{ADDITIONAL_CFLAGS} #{RSVG_CFLAGS} -I#{RbConfig::CONFIG['archdir']}]
if RbConfig::CONFIG['rubyhdrdir']
  LINUX_CFLAGS << " -I#{RbConfig::CONFIG['rubyhdrdir']} -I#{RbConfig::CONFIG['rubyhdrdir']}/#{SHOES_RUBY_ARCH}"
end

LINUX_LIB_NAMES = %W[#{RUBY_SO} cairo pangocairo-1.0 gif]

#FLAGS.each do |flag|
#  LINUX_CFLAGS << " -D#{flag}" if ENV[flag]
#end

if ENV['DEBUG']
  LINUX_CFLAGS << " -g3 -O0 "
else
  LINUX_CFLAGS << " -O "
end
LINUX_CFLAGS << " -DRUBY_1_9"
if ENV['CDEFS']
  LINUX_CFLAGS << " #{ENV['CDEFS']}"
end
DLEXT = "dylib"
#LINUX_CFLAGS << " -DSHOES_QUARTZ -Wall -Wstrict-prototypes -Wmissing-prototypes -Wmissing-declarations -Wredundant-decls -fpascal-strings #{RbConfig::CONFIG["CFLAGS"]} -x objective-c -fobjc-exceptions"
LINUX_CFLAGS << " -DSHOES_QUARTZ -Wall -fpascal-strings #{RbConfig::CONFIG["CFLAGS"]} -x objective-c -fobjc-exceptions"
LINUX_CFLAGS << " -Wno-incompatible-pointer-types-discards-qualifiers"
LINUX_LDFLAGS = "-framework Cocoa -framework Carbon -dynamiclib -Wl,-single_module INSTALL_NAME"
LINUX_LIB_NAMES << 'pixman-1' << 'jpeg.8'

OSX_SDK = '/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX10.11.sdk'
ENV['MACOSX_DEPLOYMENT_TARGET'] = '10.9'

SHOES_TGT_ARCH = 'x86_64-darwin13.0'
#SHOES_TGT_ARCH = 'x86_64-darwin14.0'

case ENV['SHOES_OSX_ARCH']
when "universal"
  OSX_ARCH = "-arch i386 -arch x86_64"
when "i386"
  OSX_ARCH = '-arch i386'
else
  OSX_ARCH = '-arch x86_64'
end

LINUX_CFLAGS << " -isysroot #{OSX_SDK} #{OSX_ARCH}"
LINUX_LDFLAGS << " #{OSX_ARCH} -L/usr/local/lib/ "

LINUX_LIBS = LINUX_LIB_NAMES.map { |x| "-l#{x}" }.join(' ')

LINUX_LIBS << " -L#{TGT_DIR} #{CAIRO_LIB} #{PANGO_LIB} #{RSVG_LIB}"
LINUX_LIBS << " -L/nfs/2014/t/tgauvrit/.brew/Cellar/giflib/4.2.3/lib -L/nfs/2014/t/tgauvrit/.brew/Cellar/jpeg/8d/lib -L/nfs/2014/t/tgauvrit/.brew/Cellar/pixman/0.34.0/lib"


# Additional Libraries
#LINUX_CFLAGS << " -I/usr/local/opt/pixman/include "
#LINUX_LDFLAGS << " -L/usr/local/opt/pixman/lib " 
#LINUX_LIBS << " -L/usr/local/opt/pixman/lib "
