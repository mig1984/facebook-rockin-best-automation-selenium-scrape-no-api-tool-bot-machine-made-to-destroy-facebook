#!/usr/bin/env ruby

# Run me to debug features of the FB class:
#
# $ ruby debug.rb
# or
# $ DEVELOPMENT=1 ruby debug.rb  (an inherited irb will be started on error to be able to dig into it more)
#
# It will start a console. Then you can do, for instance:
#
# delete 3 posts:
#
# > navigate_to my_profile_url
# > timeline(3) { |fu| delete fu }
#
# autolike 3 posts
#
# > navigate_to homepage_url
# > timeline(3) { |fu| like fu }
#
# get 3 posts (in an array):
#
# > posts = timeline(3)
#
# (but this way is useless, because if you try to like/share/comment/delete on items of the array,
# probably it wont't work, because your browser is scrolled too low already; when timeline() is used
# with it's block, it always scrolls to the right position)
#
# but you can use it to get just the first post (to be able to play with it)
#
# > fu = timeline(1).first
# > fu.el         # selenium's element
# > fu.el.text    # it's text
# > fu.el.methods # list of method - what you can do with it
#

ARGV.clear # irb wants this

require_relative 'settings'

FB_INSTANCE.debug
