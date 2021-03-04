require 'selenium-webdriver'
require 'yaml'

class FB

  # el       is the selenium's element
  # ident    md5 unique ident of the feed unit (not perfect, but works (somehow))
  # type     :normal | :sponsored | :suggested_for_you | :suggested_group | :people_you_may_know
  # header   concatenated text of first non-changing spans  
  FeedUnit = Struct.new(:el, :type, :ident, :header)

  attr_reader :driver, :wait, :timeline_already

  def initialize opts={}
    @opts = opts

    # extend this class by language dependent constants
    self.class.include opt :language_module

    if opts[:headless]
      options = Selenium::WebDriver::Chrome::Options.new args: ["headless", "window-size=1000x1200", "user-data-dir=#{opt :user_data_dir}"]
    else
      options = Selenium::WebDriver::Chrome::Options.new args: ["user-data-dir=#{opt :user_data_dir}"]
    end

    ENV['GDK_BACKEND'] = 'x11' # on wayland it does not work well for me
    $log.debug "starting chrome"
    @driver = Selenium::WebDriver.for :chrome, options: options
    $log.debug "chromium started"

    @wait = Selenium::WebDriver::Wait.new timeout: 10 # seconds
    @timeline_already = []
  end

  def done
    @driver.quit
  end
  
  def opt o
    raise "no option :#{o} given" unless @opts.has_key?(o)
    @opts[o]
  end
  
  # check if the selenium's element is still attached by the browser
  def attached? el
    begin
      el.tag_name
    rescue Selenium::WebDriver::Error::StaleElementReferenceError
      false
    else
      true
    end
  end
  
  # navigation...

  def homepage_url
    "https://www.facebook.com/"
  end
  
  def my_profile_url
    "https://www.facebook.com/#{opt :profile_path}"
  end
  
  def friends_url
    "https://www.facebook.com/#{opt :profile_path}/friends"
  end
  
  def navigate_to url, force=false
    $log.debug "navigate_to: #{url}"
    if @driver.current_url != url || force
      @driver.navigate.to url
    end
  end
  
  
  # login...
  
  # instead of logging in, do it manually and set the chrome to start in the last closed state
  # it worked for me, but I don't use it anymore, so it's not tested
  def login(username, password)
    $log.info "login..."
    navigate_to homepage_url
    $log.debug "accepting cookies"
    el = elmw "//button[contains(text(), '#{LOGIN_ACCEPT_ALL}')]"
    sleep 1
    move_to el
    sleep 1
    el.click
    sleep 2
    el = elm "//input[contains(@placeholder, '#{LOGIN_EMAIL}')]"
    el.send_keys username
    sleep 1
    el = elm "//input[contains(@placeholder, '#{LOGIN_PASSWORD}')]"
    el.send_keys password
    sleep 1
    el = elm("//button[contains(text(), '#{LOGIN_LOG_IN}')]").click
  end
  
  # load friends and return array of their names
  # cache the result in a file friends.yaml
  # unless you delete the file, it will be used next time
  def friends
    cache_in_file('friends.yaml') do
    
      $log.info "loading friends..."

      navigate_to friends_url
      
      friends = []

      loop do

        found = false
        
        $log.debug "loading anchors..."
        
        elmsw("//div[contains(@data-pagelet, 'ProfileAppSection_0')]//a[contains(@href,'https://www.facebook.com/') and not(contains(@href,'/friends')) and not(contains(@href,'/following'))]").each do |el| 

          name = el.text.strip
          
          next if name.empty?
        
          if !friends.index name
            friends << name
            found = true
          end

        end
        
        break unless found

        scroll_to_bottom # load more...
        
      end

      raise "got empty friends array" if friends.empty?

      friends
    end
  end
  


  # traverse the normal/profile timeline until max feed units found
  # scrolls to the bottom unless no more units automatically
  # continues scrolling on error, refreshes the page and starts again on exception
  #
  # expects the current url to be homepage or a profile
  # (something with the timeline)
  #
  # if a block given, each feed unit is passed into it while traversing
  #
  def timeline(max, &block)
    min_y = 0
    posts = []
    scrolled = false

    timeline_type = case @driver.current_url
      when homepage_url
        :homepage
      when my_profile_url
        :profile
      else
        raise "Can't detect a type of the current page '#{@driver.current_url}'. Go to homepage or a profile page before calling the timeline(). (Use 'navigate_to homepage_url' or 'navigate_to my_profile_url' before)."
    end

    units_path = case timeline_type
      when :homepage
        "//div[contains(@data-pagelet, 'FeedUnit')]"
      when :profile
        "//div[contains(@data-pagelet, 'ProfileTimeline')]/div"
    end

    $log.info "traversing the #{timeline_type} timeline..."

    catch :we_are_done do

      loop do
        found = 0
  
        retry_count = 0
        begin # rescue stale reference error
        
          # for each feed unit...
          elmsw(units_path).each do |el|

            # get first 0..8 spans and identify the feed unit
            header = ''
            type = :normal
            elms('.//span', el)[0..8].each do |span|   # are lazy loaded! we have to wait
              next if span.text =~ TIMELINE_DYNAMIC_SPAN_REGEX  # skip what changes frequently (date, etc.)
              throw :we_are_done if span.text =~ TIMELINE_NO_MORE_POSTS_REGEX

              if timeline_type == :homepage

                case span.text
                  when TIMELINE_SUGGESTED_FOR_YOU_REGEX
                    type = :suggested_for_you
                  when TIMELINE_SUGGESTED_GROUP_REGEX
                    type = :suggested_group
                  when TIMELINE_PEOPLE_YOU_MAY_KNOW_REGEX
                    type = :people_you_may_know
                  when TIMELINE_SPONSORED_REGEX
                    type = :sponsored
                end

              elsif timeline_type == :profile

                # there are no such types on the profile timeline => everything becomes :normal

              end

              header << span.text
            end
            
            # contains concatenated 8 first spans (but not changing ones)
            header.strip!
            
            # get concatenated sources of all images
            images = elms('.//img', el).inject('') {|s, x| s << x.attribute('src') }              
            
            # compute an unique ident of the feed unit
            ident = Digest::MD5.hexdigest(header + images)
            
            # get the Y position of the element
            y = el.attribute('offsetTop').to_i

            # process the element unless already; don't try to go backward
            if !@timeline_already.index(ident) && y > min_y  

              $log.info "feed unit: ident=#{ident}, type=#{type}, y=#{y}"
              
              found += 1

              # create the FeedUnit object
              fu = FeedUnit.new(el, type, ident, header)
              posts << fu

              scroll_to el.attribute('offsetTop').to_i
              sleep 2 # scrolling might be slow

              if block

                # move mouse to the homepage button, otherwise it hovers random elements and tooltips
                move_to elmw("//a[contains(@aria-label, '#{HOMEPAGE_LABEL}')]")

                begin

                  block.call fu

                rescue Selenium::WebDriver::Error::JavascriptError, 
                      Selenium::WebDriver::Error::StaleElementReferenceError, 
                      Selenium::WebDriver::Error::TimeoutError, 
                      StandardError
                  $log.error "TIMELINE ERROR: #{$!}"
                  $log.debug $!.backtrace
                  if opt :development
                    binding.irb
                  end
                  # go on to a next post...
                rescue Interrupt # CTRL-C
                  raise
                rescue Exception
                  $log.fatal "TIMELINE EXCEPTION: #{$!}"
                  $log.debug $!.backtrace
                  if opt :development
                    binding.irb
                  else
                    raise
                  end
                end

              end # block
              
              min_y = y if attached? el  # when post is deleted, element is not attached (disappeared) => do not update the position
              
              @timeline_already << ident # next time it will skip

              throw :we_are_done if posts.length==max

            end # already

          end # each feed unit
          
        rescue Selenium::WebDriver::Error::StaleElementReferenceError  
          
          # divs in the profile timeline are lazy loaded. In the beginning, elmsw gets 8 divs. When you scroll down, some of these divs 
          # are being replaced with the lazy loaded contents -> therefore the original div is gone and it's reference as well
          # -> we have to restart the elmsw
          retry_count += 1
          if retry_count<=2
            retry
          else
            raise "retried, but still getting stale reference error"
          end
          
        else
          
          retry_count = 0
          
        end

        if found == 0 # nothing new found?
          if ! scrolled
            scroll_to_bottom
            scrolled = true
            sleep 4
          else
            $log.info 'no more new posts'
            throw :we_are_done
          end
        else
          scrolled = false
        end

      end # loop
    
    end # catch we_are_done

    posts
  end
  
  
  # checks...
    
  def is_my_own? fu
    fu.header =~ /#{opt :my_name}/
  end
    
    
  # deletion
  
  def delete fu
    $log.info "delete..."
    button = elmw(".//div[contains(@aria-label, '#{DELETE_ACTIONS}')]", fu.el)
    button.click
    sleep 2
    #elmw("//div[@role='menu']")  # wait for menu
    item = elmw("//div[@role='menu']//span[contains(text(), '#{DELETE_TRASH}') or contains(text(), '#{DELETE_REMOVE_TAG}') or contains(text(), '#{DELETE_HIDE}')]")
    txt = item.text # (the element will disappear after clicking)
    item.click
    if txt =~ /#{DELETE_TRASH}/
      sleep 2
      button = elmw("//div[@role='dialog']//span[text()='#{DELETE_CONFIRM}']")
      button.click
    end
    sleep 2 # it has to disappear from the timeline
    $log.debug "deleted."
  end
  
  
  # likes..
  
  # select second most liked icon, the most liked is usually the default
  def second_most_liked_icon likes
    sorted = likes.sort_by { |k,v| v } # ["Haha", 10]
    if sorted.length>1
      sorted[-2][0]  # second maximum, first is usually the default "To se mi libi"
    else
      sorted[0][0]   # there is just one icon
    end
  end
  
  def liked_already? fu
    @liked_already ||= {}
    return @liked_already[fu.ident] if @liked_already.has_key? fu.ident
    likes fu  # will update the @liked_already
    @liked_already[fu.ident]
  end
  
  # get and cache likes
  # return Hash, for instance {"Haha"=>10, "To se mi líbí"=>5, "Péče"=>3}
  def likes fu
    cache("likes_#{fu.ident}") do
      
      $log.debug "getting likes..."

      likes = {}
      elms(".//span[contains(@aria-label, '#{LIKES_ICONS_LABEL}')]//img", fu.el).each do |icon|
        move_to(icon)
        $log.debug "- waiting for a popup"
        sleep 2
        move_to(icon)  # otherwise first popup has no text unless chromium is visible, dunno why
        
        if tooltip = elmw('//span[@role="tooltip"]') # when there are no likes yet, there is no tooltip as well
          
          txt = tooltip.text
          #"To se mi líbí\nTomáš Ševčík\nOldřich Pibyl\nMirek Almášy\nJan Ulip\nJan Řehák\nRadek Döme\nJindřiš Homolacova\nJan Valíček\nDagmar Dádula Kameníková\nRené Větříšek\nIveta Vrzalová\nIva Ondráčková\nLenka Mušková\nMartina Abrhámová\nDavid Pelzl\nEdita Ulrichová\nDJarek Řáldes\nMoncass Šanderová\nLenka Koncelova\na 1 dalších…"

          if txt =~ /#{opt :my_name}/
            $log.debug "  (already liked)"
            @liked_already ||= {}
            @liked_already[fu.ident] = true
          end

          raise("got empty popup") if txt.strip.empty?

          a = txt.split(/\n/)
          icon_type = a.first
          if a.last =~ LIKES_OTHERS_REGEX
            x_others = a.last.gsub(/[^\d]+/,'').to_i
            total = a.length-2 + x_others
          else
            total = a.length-1
          end
          likes[icon_type] = total
        end
      end

      $log.debug likes.inspect

      likes 
    
    end # cache
  end
  
  
  # do like the timeline element, but only if at least specified minimum of people already liked it
  def like fu, minimum=0

    $log.info "like..."
    
    likes = likes fu

    sum = likes.values.sum
    if sum<minimum
      $log.debug "- #{sum} likes < minimum #{minimum}, return false"
      return false
    end
    
    begin
      button = elmw ".//div[@aria-label='#{LIKE_BUTTON_LIKE_LABEL}' or @aria-label='#{LIKE_BUTTON_LOVE_LABEL}' or @aria-label='#{LIKE_BUTTON_CARE_LABEL}' or @aria-label='#{LIKE_BUTTON_HAHA_LABEL}' or @aria-label='#{LIKE_BUTTON_WOW_LABEL}' or @aria-label='#{LIKE_BUTTON_SAD_LABEL}' or @aria-label='#{LIKE_BUTTON_ANGRY_LABEL}']", fu.el
    rescue
      $log.error "no button found"
      return false
    end    

    $log.debug "- hovering the button"    
    move_to button

    if likes.empty?  # no likes yet? (i.e. no icons?)

      button.click

    else

      icon_name = second_most_liked_icon likes

      $log.debug "- waiting for icons"
      icon_el = elmw "//div[@role='toolbar']//div[@aria-label='#{icon_name}']" # is the only element on the page

      sleep 2
      $log.debug "- hovering #{icon_name}"
      move_to(icon_el)
      sleep 1
      $log.debug "- clicking #{icon_name}"
      icon_el.click
      sleep 2
      
    end

    true
  end

  # commenting...
  
  def number_of_comments fu
    if fu.el.text.match NUMBER_OF_COMMENTS_REGEX
      $1.to_i
    else
      0
    end
  end  

  def comment fu, text
    $log.info 'comments...'
    begin
      button = elmw ".//div[@aria-label='#{COMMENTS_BUTTON_LABEL}']", fu.el
    rescue
      $log.error "no button found"
      return false
    end
    button.click
    input = elmw ".//div[@aria-label='#{COMMENTS_INPUT_LABEL}']", fu.el
    move_to input
    input.click
    $log.debug "- entering text: #{text}"
    keyboard(text, input)
    keyboard(:enter, input)
  end
  
  # sharing...
  
  def number_of_shares fu
    if fu.el.text.match NUMBER_OF_SHARES_REGEX
      $1.to_i
    else
      0
    end
  end  

  def share fu
    $log.info "sharing..."
    begin
      button = elmw ".//div[@aria-label='#{SHARE_BUTTON_LABEL}']", fu.el
    rescue
      $log.error "no button found"
      return false
    end
    button.click
    $log.debug "- on my own timeline"
    sleep 1.5
    begin
      option = elmw("//*[contains(text(), '#{SHARE_OWN}') or contains(text(), '#{SHARE_PUBLIC}')]") # popup
    rescue
      $log.error "no sharing options found"
      return false
    end
    option.click 
  end
  
  # working with elements...

  def elm s, context=@driver
    context.find_element :xpath, s
  end

  def elms s, context=@driver
    context.find_elements :xpath, s
  end

  def elmw s, context=@driver
    @wait.until do
      context.find_element :xpath, s
    end
  end

  def elmsw s, context=@driver
    @wait.until do
      context.find_elements :xpath, s
    end
  end

  # return position of the element
  def y el
    el.attribute('offsetTop')
  end

  # return pretty-printed element (string)
  # useful while debugging on the irb commandline
  def dump el
    html = el.attribute('outerHTML')
    doc = Nokogiri::XML(html,&:noblanks)
    doc.to_s
  end
  
  # scrolling...
  
  # to load more posts, etc.
  def scroll_to_bottom
    $log.debug "scroll_to_bottom"
    scroll_to( @driver.execute_script "return document.body.scrollHeight || document.documentElement.scrollHeight" )
  end

  # simulate slow scroll (to the element or to a specified position)
  # the diff is to adjust the position
  def scroll_to el_or_pos, diff=0
    y = if el_or_pos.is_a?(Integer)
      el_or_pos
    else
      el_or_pos.attribute('offsetTop')
    end
    $log.debug "scroll_to: #{y}"
    @driver.execute_script "scrollY=#{y.to_i+diff}; var scroll = function() { var step = scrollY - document.documentElement.scrollTop; if (Math.abs(step)>1000) { if (step<-100) step=-100; if (step>100) step=100; } else { if (step<-10) step=-10; if (step>10) step=10; } window.scrollTo(0, document.documentElement.scrollTop+step); if (step!=0) setTimeout(scroll, 5); }; scroll()"
    sleep 2
  end

  # move mouse over the element
  def move_to el
    @driver.action.move_to(el).perform
  end

  # simulate typing on keyboard
  # the text can be :enter (instead of string) to submit a message
  def keyboard txt, el
    if txt.is_a?(String)
      txt.each_char { |x| el.send_keys(x); sleep(rand(3)*0.01); }
    else
      sleep 2
      el.send_keys(txt)
    end
  end
  
  # debug...
  
  # use this to start an irb console inside an instance of this class
  # it's called 'debug' because irb adds some methods when started and one of them is called 'irb', so next time if you call the method, it would work differently!
  def debug
    require 'irb'
    binding.irb
  end
  
  private def cache key, &block
    @cache ||= {}
    return @cache[key] if @cache.has_key?(key)
    @cache[key] = block.call
  end
  
  private def cache_in_file(filename, &block)
    cache("cache_in_file_#{filename}") do
    
      if File.exist?(filename)
        YAML::load_file(filename)
      else
        content = block.call
        File.open(filename, 'w+') {|f| f.puts content.to_yaml }
        content
      end

    end
  end

end


# TODO

  #def notifications &block
    #loop do
      #el = elmw('//div[contains(@aria-label, "Upozornění")]')
      #el.click
      #sleep 1
      #elms = elmsw('//div[text()="Nepřečteno"]/..//img')
      #elms.each do |el|
        #move_to(el)
        #el.click
        #sleep 5
        #block.call el
      #end
      #break if elms.empty?
    #end
  #end
  
