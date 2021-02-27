#!/usr/bin/env ruby

# uncomment the $DEBUG global variable to see some more messages from the selenium driver
#  $DEBUG = true

DEVELOPMENT   = ENV.has_key?('DEVELOPMENT')
HEADLESS      = ENV.has_key?('HEADLESS')
DO_SHARING    = true
DO_COMMENTING = false

ARGV.clear

#############

# This method does the job. Change it as you like!

def process_timeline(fb)
  
  # preload and cache friends
  fb.friends 

  # some regular expressions to identify a post and if it should be liked/shared/commented
  regex_friends = /#{ fb.friends.join('|') }|Stará Praha/
  regex_do_not_like = /XTV|Bytujeme/
  regex_do_not_share = /XTV|Bytujeme|profilový obrázek|Valento|Šlachta/
  regex_do_not_comment = /Jindřich Parma|Janek Ruzicka|Sudety|Sičakova|Bouffie|Juki/
  
  # traverse up to 60 feed units
  fb.timeline(60) do |fu|

    # skip my own post/repost

    if fb.is_my_own? fu
      $log.debug "- is my own post/repost"
      next 
    end

    # like 
    
    liked_now = false
    
    if fu.type == :normal
      if fu.header =~ regex_friends
        $log.debug "- is a friend"
        # like everything from my friends
        liked_now = fb.like(fu) unless fb.liked_already? fu
      elsif rand(2)==0 && fu.el.text !~ regex_do_not_like
        $log.debug "- is not a friend"
        # there must be at least 4 likes already
        liked_now = fb.like(fu, 4) unless fb.liked_already? fu
      else
        $log.debug "- not likeing"
      end
      # other, i.e. sponsored or suggested feed units => not liked
    end
    
    # the like is also used to detect if a post has been commented/shared already
    # it means, if I share/comment, I also give a like
    if liked_now

      if DO_SHARING
      
        if fu.type==:normal && fu.header !~ regex_do_not_share && fu.header =~ regex_friends
          fb.share fu
          sleep rand(2)
        end
        
      end

      if DO_COMMENTING

        if fu.el.text !~ regex_do_not_comment && (fu.type!=:sponsored || fb.number_of_comments(fu)>15) && (fu.type!=:suggested_for_you || fb.number_of_comments(fu)>20)
          fb.comment(fu, "Revoluce!")
          sleep rand(2)
        end

      end
    
    end # liked
      
  end
end

#############

require 'logger'
$log = Logger.new(STDERR)

# load a language module
require_relative 'set_cz'                                  # or set_en_us.rb

# modify this...
require_relative 'fb'
fb = FB.new set: SetCZ,                                    # or SetEN_US - see the module name in the corresponding file
            development: DEVELOPMENT,
            headless: HEADLESS,
            user_data_dir: "/home/web/fb/chrome-profile",  # absolute path to the browser's profile
            my_name: 'Jan Molič',                          # displayed name
            profile_path: 'molic.jan'                      # i.e. https://www.facebook.com/molic.jan

#############

if DEVELOPMENT
  
  require 'irb'
  binding.irb
  
  # now on the console:
  #
  # a) type 'process_timeline(fb)' or
  # b) fb.* to call a method on the fb instance, or
  # c) fb.debug to start an inherited irb console in the context of the fb instance

else

  # main loop
  # process up to 60 posts and then sleep 6-12 hours
  
  loop do
    begin
      process_timeline(fb)
      sleep rand(3600*6)+3600*6
    rescue Interrupt # CTRL-C
      raise
    rescue Exception
      $log.error "EXCEPTION: #{$!} #{$!.backtrace}"
      sleep 5
    end
  end

end
