#!/usr/bin/env ruby

require 'js_base'
require 'open3'

class MyLogCatApp


  def initialize
    @verbose = false
    @input_buffer = ''
    @input_cursor = 0
  end

  def clear_screen
    printf "\033c"
  end

  # Return the ASCII code last key pressed, or nil if none
  def read_user_char
    char = nil
    # Don't read keyboard more than x times per second
    time = Time.new
    if !@prev_time || time - @prev_time >= 0.25
      @prev_time = time
      begin
        system('stty raw -echo') # => Raw mode, no echo
        char = (STDIN.read_nonblock(1) rescue nil)
      ensure
        system('stty -raw echo') # => Reset terminal mode
      end
    end
    char
  end

  def read_nonblocking(io)
    begin
      # Using a small buffer size seems to improve performance!
      # Otherwise there can be significant delays displaying multiline bursts
      # e.g., stack traces
      data = io.read_nonblock(10)
      @input_buffer << data
      s = @input_buffer[@input_cursor..-1]
      # If linefeed was read, return characters leading up to it
      lf = s.index("\n")
      if lf
        @input_cursor += lf
        line = @input_buffer.slice!(0...@input_cursor+1).chomp
        @input_cursor = 0
        return line
      end
    rescue Errno::EAGAIN
    end
    nil
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

    clear_screen

    if options[:clear]
      scall("adb logcat -c")
    end

    stdin, stdout, stderr = Open3.popen3("adb logcat")
    quit_flag = false
    while !quit_flag

      x = read_nonblocking(stdout)
      y = nil

      # Only read keyboard if no input
      if x.nil?
        y = read_user_char
      end

      process_line(x) if x
      if y
        puts # Seems to echo the character; so print linefeed for less confusion
        case y
        when 'q'
          puts "...goodbye"
          quit_flag = true
        when 'c'
          clear_screen
        else
          puts "...(ignoring '#{y}')"
        end
      end
    end

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
