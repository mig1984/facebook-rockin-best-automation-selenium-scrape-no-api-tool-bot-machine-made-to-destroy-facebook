#!/usr/bin/env ruby

# Run me to do autolike/autocomment/autoshare.
#
# $ ruby bot.rb
#

require_relative 'settings'

# this method does the job
def process_timeline(fb)
  
  # preload and cache friends
  fb.friends

  # create regular expression matching all my friends
  regex_friends = /#{ fb.friends.join('|') }/
  
  # go to homepage
  fb.navigate_to fb.homepage_url

  # traverse up to 60 feed units
  fb.timeline(60) do |fu|

    # skip my own post/repost

    if fb.is_my_own? fu
      $log.debug "- is my own post/repost"
      next 
    end

    # do like
    
    liked_now = false
    
    if fu.type == :normal
      if fu.header =~ regex_friends
        $log.debug "- is a friend"
        # like everything from my friends
        liked_now = fb.like(fu) unless fb.liked_already? fu
      elsif rand(2)==0 && fu.el.text !~ REGEX_DO_NOT_LIKE
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
      
        if fu.type==:normal && fu.header !~ REGEX_DO_NOT_SHARE && fu.header =~ regex_friends
          fb.share fu
          sleep rand(2)
        end
        
      end

      if DO_COMMENTING

        if fu.el.text !~ REGEX_DO_NOT_COMMENT && (fu.type!=:sponsored || fb.number_of_comments(fu)>15) && (fu.type!=:suggested_for_you || fb.number_of_comments(fu)>20)
          fb.comment(fu, COMMENT_TEXT)
          sleep rand(2)
        end

      end
    
    end # liked

    # pretend reading
    case fu.type
      when :normal
        sleep(rand(8))
      when :sponsored
      else
        sleep(rand(3))
    end

  end
end


# main loop
loop do
  begin
    process_timeline(FB_INSTANCE)
    sleep rand(3600*6)+3600*6
  rescue Interrupt # CTRL-C
    raise
  rescue Exception
    $log.error "EXCEPTION: #{$!} #{$!.backtrace}"
    sleep 5
  end
end
