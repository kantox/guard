require "guard/cli"

module Guard
  class ArubaAdapter
    def initialize(argv, stdin = STDIN, stdout = STDOUT, stderr = STDERR,
                   kernel = Kernel)
      @argv = argv
      @stdin = stdin
      @stdout = stdout
      @stderr = stderr
      @kernel = kernel
      ::Guard::UI.options = ::Guard::UI.options.merge(flush_seconds: 0)
    end

    def execute!
      exit_code = execute
      # Proxy our exit code back to the injected kernel.
      @kernel.exit(exit_code)
    end

    def execute
      # Thor accesses these streams directly rather than letting
      # them be injected, so we replace them...
      $stderr = @stderr
      $stdin = @stdin
      $stdout = @stdout

      # Run our normal Thor app the way we know and love.
      ::Guard::CLI.start(@argv)

      # Thor::Base#start does not have a return value, assume
      # success if no exception is raised.
      0
    rescue StandardError => e
      # The ruby interpreter would pipe this to STDERR and exit 1 in the case
      # of an unhandled exception
      b = e.backtrace
      b.unshift("#{b.shift}: #{e.message} (#{e.class})")
      @stderr.puts(b.map { |s| "\tfrom #{s}" }.join("\n"))
      1
    rescue SystemExit => e
      e.status
    ensure
      # flush the logger so the output doesn't appear in next CLI invocation
      ::Guard::UI.logger.flush
      ::Guard::UI.logger.close
      ::Guard::UI.reset_logger

      # ...then we put them back.
      $stderr = STDERR
      $stdin = STDIN
      $stdout = STDOUT
    end
  end
end
