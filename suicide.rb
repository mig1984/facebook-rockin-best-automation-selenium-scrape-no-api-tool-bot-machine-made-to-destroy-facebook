#!/usr/bin/env ruby

# Run me to remove all your posts.
#
# $ ruby suicide.rb
#

require_relative 'settings'

# this method does the job
def process_timeline(fb)
  fb.navigate_to fb.my_profile_url, true

  # try again what has failed
  fb.timeline_already.clear

  # traverse up to 60 feed units
  res = fb.timeline(60) do |fu|
    fb.delete fu
  end

  res.length
end

# main loop
loop do
  begin
    if process_timeline(FB_INSTANCE) == 0
      $log.info "All posts have been removed."
      break
    end
  rescue Interrupt # CTRL-C
    raise
  rescue Exception
    $log.error "EXCEPTION: #{$!} #{$!.backtrace}"
    sleep 10
  end
end
