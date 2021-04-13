require 'open3' unless RUBY_ENGINE == 'mruby'

module SUSE
  module Toolkit
    # Provides basic system calls interface
    module SystemCalls
      include Connect::Logger

      def execute_raw(cmd)
        log.debug("Executing raw: '#{cmd}'")
        output, error, status = Open3.capture3({ 'LC_ALL' => 'C' }, cmd) { |_stdin, stdout, _stderr, _wait_thr| stdout.read }
        log.debug("Output: '#{output.strip}'") unless output.empty?
        log.debug("Error: '#{error.strip}'") unless error.empty?
        [output, error, status]
      end

      def execute(cmd, quiet = true, valid_exit_codes = [0]) # rubocop:disable CyclomaticComplexity
        log.debug("Executing: '#{cmd}' Quiet: #{quiet}")
        output, error, status = execute_raw(cmd)

        # Catching interactive failures of zypper. --non-interactive always returns with exit code 0 here
        if !valid_exit_codes.include?(status.exitstatus) || error.include?('ABORT request')
          log.error("command '#{cmd}' failed")
          # NOTE: zypper with formatter option will return output instead of error
          # e.g. command 'zypper --xmlout --non-interactive products -i' failed
          error = error.empty? ? output.strip : error.strip
          e = (cmd.include? 'zypper') ? Connect::ZypperError.new(status.exitstatus, error) : Connect::SystemCallError
          raise e, error
        end
        output.strip unless quiet
      end
    end
  end
end
