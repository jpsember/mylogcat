#!/usr/bin/env ruby

require 'js_base'
require 'open3'

class MyLogCatApp


  def initialize
    @verbose = false

    # Buffer to store characters read, until we get a complete line
    @input_buffer = ''

    # Complete lines that have been buffered
    @buffered_lines = []

    # Process id we think belongs to ours, or nil; this may change several times,
    # each time we encounter '---- Start of...'
    @our_process_id = nil
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
      while true
        lf = data.index("\n")
        if !lf
          @input_buffer << data
          break
        end

        tail = data[0...lf]
        data = data[1+lf..-1]

        line = @input_buffer + tail
        @buffered_lines << line
        @input_buffer = ''
      end
    rescue Errno::EAGAIN
    end
    return @buffered_lines.shift
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


  # The owner fields may contain parentheses and colons, so just make sure we can
  # find a '(9999):' later on
  LINE_EXP = /^([A-Z])\/(.+)\(( *\d+)\):\s?(.*)$/

  AUX_EXP = /^\-+ beginning of \/dev\/log\/(.*)$/

  # If our program logs strings beginning with !!ABCD!!, we interpret these as
  # special commands to mylogcat: START, CLS, ...
  OUR_TOKEN = /^!!([A-Z]+)!!(.*)$/

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
      our_token = nil
      m2 = OUR_TOKEN.match(message)
      if m2
        our_token = m2[1]
        message = m2[2]
      end

      # Apply our desired filtering...

      return if tag_type == 'V' || tag_type == 'D'

      allow = false
      allow ||= (tag_type == 'E' && owner == 'AndroidRuntime')
      if owner == 'System.out'
        if our_token == 'START'
          @our_process_id = process_id
          clear_screen
        end
        # If our process id is unknown, or if it matches the current one, allow it
        if !@our_process_id || @our_process_id == process_id
          allow ||= true
        end
      end

      return if !allow

      if tag_type == 'E'
        message = color_red(message)
      end

      puts message
      if our_token == 'CLS'
        clear_screen
      end

      STDOUT.flush
    else
      # Look for messages that match some unusual but not unexpected patterns
      return if AUX_EXP.match(content)

      puts "<<<no match!>>> "+content
    end
  end

end


if __FILE__ == $0
  MyLogCatApp.new.run()
end
