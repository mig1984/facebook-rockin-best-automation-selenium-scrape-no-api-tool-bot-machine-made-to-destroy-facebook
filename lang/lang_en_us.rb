module LangEN_US
  
  # this module will be included into the FB class on it's initialize

  HOMEPAGE_LABEL = 'Home'
  
  LOGIN_ACCEPT_ALL = 'Accept All'
  LOGIN_EMAIL = 'Email'
  LOGIN_PASSWORD = 'Password'
  LOGIN_LOG_IN = 'Log In'
  
  TIMELINE_DYNAMIC_SPAN_REGEX = /\dm|\dh|Yesterday|Today|(January|February|March|April|May|Jun|July|August|September|October|November|December) \d+/
  TIMELINE_NO_MORE_POSTS_REGEX = /No posts available/  
  TIMELINE_SUGGESTED_FOR_YOU_REGEX = /Suggested for You/
  TIMELINE_SUGGESTED_GROUP_REGEX = /Suggested group/ # FIXME
  TIMELINE_PEOPLE_YOU_MAY_KNOW_REGEX = /People You May Know/i
  TIMELINE_SPONSORED_REGEX = /Sponsored/
  
  FRIENDS_REGEX = /\d mutual friends/
  
  NUMBER_OF_SHARES_REGEX = /([\d.]+) Shares/
  NUMBER_OF_COMMENTS_REGEX = /([\d.]+) Comments/
  
  LIKE_BUTTON_LIKE_LABEL  = 'Like'
  LIKE_BUTTON_LOVE_LABEL  = 'Love'
  LIKE_BUTTON_CARE_LABEL  = 'Care'
  LIKE_BUTTON_HAHA_LABEL  = 'Haha'
  LIKE_BUTTON_WOW_LABEL   = 'Wow'
  LIKE_BUTTON_SAD_LABEL   = 'Sad'
  LIKE_BUTTON_ANGRY_LABEL = 'Angry'
  
  LIKES_ICONS_LABEL = 'See who reacted to this'
  LIKES_OTHERS_REGEX = /and \d+ more/
  
  COMMENTS_BUTTON_LABEL = 'Leave a comment'
  COMMENTS_INPUT_LABEL = 'Write a comment'
  
  SHARE_BUTTON_LABEL = 'Send this to friends or post it on your timeline.'
  SHARE_OWN = 'Share now (Custom)'
  
  DELETE_ACTIONS = 'Actions for this post'
  DELETE_TRASH = 'Move to trash'
  DELETE_REMOVE_TAG = 'Remove tag'
  DELETE_HIDE = 'Hide from profile'
  DELETE_CONFIRM = 'Move'

end
