#!/usr/bin/env ruby

# uncomment $DEBUG global variable to see some more messages from the selenium driver
#  $DEBUG = true

HEADLESS      = ENV.has_key?('HEADLESS')
DEVELOPMENT   = ENV.has_key?('DEVELOPMENT')

# do not change this
require 'logger'
$log = Logger.new(STDERR)

# load a language module - depends on the language of your profile
require_relative 'lang/lang_en_us'

# modify this...
require_relative 'lib/fb'
FB_INSTANCE = FB.new language_module: LangEN_US,                    # or LangCZ - see the module name in the corresponding file
                     development: DEVELOPMENT,
                     headless: HEADLESS,
                     user_data_dir: "/home/web/fb/chrome-profile",  # absolute path to the browser's profile
                     my_name: 'Jan Molič',                          # displayed name
                     profile_path: 'molic.jan'                      # i.e. https://www.facebook.com/molic.jan

# bot.rb only settings
DO_SHARING           = false
DO_COMMENTING        = false
REGEX_DO_NOT_LIKE    = /XTV|Bytujeme/
REGEX_DO_NOT_SHARE   = /XTV|Bytujeme|profilový obrázek|Valento|Šlachta/
REGEX_DO_NOT_COMMENT = /Jindřich Parma|Janek Ruzicka|Sudety|Sičakova|Bouffie|Juki/
COMMENT_TEXT         = 'Revoluce!'
