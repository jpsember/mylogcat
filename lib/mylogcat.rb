#!/usr/bin/env ruby

require 'js_base'
require 'open3'

class MyLogCatApp


  def initialize
    @verbose = false
  end

  def run(argv = nil)
    argv ||= ARGV
    p = Trollop::Parser.new do
      opt :verbose, "verbose operation"
      opt :clear,   "clear log file beforehand"
    end

    options = Trollop::with_standard_exception_handling p do
      p.parse(argv)
    end

    @verbose = options[:verbose]

    if options[:clear]
      scall("adb logcat -c")
    end

    stdin, stdout, stderr = Open3.popen3("adb logcat")
    while true
      x = stdout.readline
      process_line(x)

      if false
        y = read_user_char
        break if y == 'q'
      end
    end

  end

  def read_user_char

    # Can't get this to work; want to allow ctrl-c (or command-c) to exit
    # Signal.trap("INT") do
    #   exit
    # end

    system("stty raw -echo") #=> Raw mode, no echo
    char = STDIN.getc
    system("stty -raw echo") #=> Reset terminal mode
    char
  end

  LINE_EXP = /^([A-Z])\/([^\(]+)\(([^\)]+)\): (.*)$/

  def color_red(s)
    "\033[31m#{s}\033[0m"
  end

  def process_line(content)
    m = LINE_EXP.match(content)

    if m

      tag_type = m[1]
      owner = m[2]
      process_id = m[3]
      message = m[4]

      # Apply our desired filtering...

      return if tag_type == 'V' || tag_type == 'D'
      allow = false
      allow ||= (tag_type == 'E' && owner == 'AndroidRuntime')
      allow ||= (owner == 'System.out')
      return if !allow

      if tag_type == 'E'
        message = color_red(message)
      end

      puts message
    else
      puts content
    end
  end

end


if __FILE__ == $0
  MyLogCatApp.new.run()
end
