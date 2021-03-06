require "fxList2"
require "eeprom"
require "fileutils"
require "open3"
require "modelFile"
include FileUtils



SELUSER_RCLOADED=1000


class FXListRcItem < FXListGenericItem
    #attr_accessor :txt, :icon, :lev #, :list
    #attr_reader :txt, :icon, :lev #, :list
  LPAD=4
  def kind; :file ; end
  def empty?
    not @name
  end
  def select(what=true)
    #puts "select #{what} #{empty?}"
    super if ! empty?
  end

  def initialize(alist,nr)#,lev)#,isDir)
    @alist,@nr=alist,nr
    @selected=false
    set(nil,nil,nil)
  end
  def set(icon,name,size)#,lev)#,isDir)
    # @name,@icon,@lev,@isDir=name,icon,lev,isDir
    @icon,@name,@size=icon,name,size
  end
  def readFile
    @alist.getNameContents(@nr)[1]
  end

  # D      Dir
  # |- D   SubDir
  # |  |-F
  # |  |-F
  # |  \-D
  # |    |-F
  # |    |-F
  # |    \-F
  # |- F   File
  # |- F   File
  # \- F   File
  #
  #IDT = 15
  def draw(dc,x,y,w,h,i,data)
    # white  = FXRGB(255,255,255)
    # white2 = FXRGB(225,240,235)
    # bgCol = i%2==0 ? white  : white2
    bgCol = i%2==0 ? BG_WHITE1  : BG_WHITE2
    #cdiff = white-bgCol
    fgCol = list.textColor;
    #i%2==0 ? list.backColor : FXRGB(240,245,250))
    if selected? #and data != 1
      bgCol = list.selbackColor 
      fgCol = list.seltextColor;
    end
    #bgCol -= FXRGB(60,60,60) if data== :Nr
    #dc.setForeground(data== :Nr ? $app.baseColor-cdiff : bgCol)
    dc.setForeground(bgCol)
    dc.fillRectangle(x,y,w,h);
    x+=LPAD

    dc.setForeground(fgCol);
    font=list.font
    th=font.getFontHeight()
    asc=font.getFontAscent()
    dc.setFont(font);
    case data
    #when :Icon
    #  dc.drawIcon(@icon,x,y) if @icon
    when :Nr
      #dc.drawText(x,y+(h-th)/2+asc,"%2d"%@nr) if @nr
      x=8+drawNumIcon(dc,x,y,w,h,@nr,$minidoc) #if @kind==:file

    when :Name
      if @name
        dc.drawText(x,y+(h-th)/2+asc,@name)
      else
        dc.setForeground(i%2==0 ? BG_WHITE2  : BG_WHITE1)
        dc.drawText(x,y+(h-th)/2+asc,"e m p t y")
      end
    when :Size
      dc.drawText(x,y+(h-th)/2+asc,@size.to_s)if @size
    end

    #dc.fillRectangle(x+2,y,5,9);
    #printf "%08x %08x",list.seltextColor,list.textColor
    #dc.setForeground( list.textColor );

  end
  def getHeight()
    # puts "h1=#{list.font.getFontHeight()} h2=#{@icon.height}"
    #return @h if @h
    # @h=list.font.getFontHeight()+2
    # @h=[@icon.height+2,@h].max if @icon
    # @h
    20
  end
  def handle(hindex,dx,dy,sender,sel,event)
    #return super if hindex== #click at icon
    false
  end
end



class RcList < FXGroupBox
  include ModelFileUtils
  def initialize(parent,prefDialog)
    @prefDialog=prefDialog
    #gbr=FXGroupBox.new(parent, "RC" ,LAYOUT_FILL_Y|GROUPBOX_NORMAL|GROUPBOX_TITLE_CENTER|FRAME_RIDGE, 0,0,0,0, 0,0,0,0, 0,0) # x y w h  l r t b  h v
    # gbr=self
    @myId = "rcList#{rand(10000)}"
    super(parent, "th9x" ,LAYOUT_FILL_Y|GROUPBOX_NORMAL|GROUPBOX_TITLE_CENTER|FRAME_RIDGE, 0,0,0,0, 10,10,9,5, 0,0) # x y w h  l r t b  h v
    uf=FXHorizontalFrame.new(self, LAYOUT_CENTER_X, 0,0,0,0, 0,0,0,0, 0,0)
    FXLabel.new(uf,"Usage: ",nil,LAYOUT_CENTER_X)
    @usageLab = FXLabel.new(uf,"-",nil,LAYOUT_CENTER_X)
    
    @list = FXList2.new(self,LAYOUT_FILL_X|LAYOUT_FIX_HEIGHT|FRAME_SUNKEN,@myId,nil,0,0,0,16*20+26,0,0,0,0,0,0)
    @list.backColor = parent.backColor
    @list.appendHeader("Nr",  nil, 50, :Nr)
    @list.appendHeader("",  iconFromDat("flag.png"), 24, :Icon)
    @list.appendHeader("Modelname",  nil, 100,:Name)
    @list.appendHeader("Size",  nil, 40,:Size)
    # @list.connect(SEL_KEYPRESS){|sender,sel,event|
    #  @keyDispatcher.onKeypress(event.code,event.state,event.time)
    #}
    #@list.clear
    
    @userConnects={}
    @rcItems=[]
    16.times{|i|
      @rcItems[i]=it=FXListRcItem.new(self,i+1)
      @list.appendItem(nil,it) 
    }
    
    hfc=FXHorizontalFrame.new(self, LAYOUT_CENTER_X, 0,0,0,0, 0,0,0,0, 0,0)
    hfb=FXHorizontalFrame.new(hfc, LAYOUT_CENTER_X, 0,0,0,0, 0,0,10,10, 10,0)
    sze=40
    
    FXArrowButton.new(hfb,nil,0,FRAME_RAISED|FRAME_THICK|ARROW_UP|LAYOUT_FIX_WIDTH|LAYOUT_FIX_HEIGHT,0,0,sze,sze){|a|
      a.arrowSize=30
      a.connect(SEL_COMMAND) {
        rcLoad()
        checkUserConnects(self,MKUINT(0,SELUSER_RCLOADED),nil)
      }
    }
    @progress=FXProgressBar.new(hfb,nil,0, PROGRESSBAR_DIAL|LAYOUT_FIX_WIDTH|LAYOUT_FIX_HEIGHT,0,0,sze,sze,*[0]*4 ) 
    
    FXArrowButton.new(hfb,nil,0,FRAME_RAISED|FRAME_THICK|ARROW_DOWN|LAYOUT_FIX_WIDTH|LAYOUT_FIX_HEIGHT,0,0,sze,sze){|a|
      #a.arrowSize=30
      a.connect(SEL_COMMAND) {
        rcSave()
      }
    }
    
    
    @th9x=FXLabel.new(self,"",$icnth9x,LAYOUT_CENTER_X)

    
    @mpop = FXPopup.new(self)
    #FXMenuCaption.new(@mpop,"Caption")
    #FXMenuSeparator.new(@mpop)
    FXMenuCommand.new(@mpop,"Rename..").connect(SEL_COMMAND){|sender,sel,event|
      @list.items.each_with_index{|item,i|
        if item.selected?
          fi = i+1
          ret = renameFileDialog(@rcFiles[fi]) 
          @rcFiles[fi] = ret if ret
        end
      }
      @list.killSelection()
      refresh()
    }
    FXMenuCommand.new(@mpop,"Delete").connect(SEL_COMMAND){|sender,sel,event|
      @list.items.each_with_index{|item,i|
        if item.selected?
          @rcFiles[i+1]=nil #[nil,""]
        end
      }
      @list.killSelection()
      refresh()
    }
    @list.connect(SEL_CLICKED){|sender,sel,data|
      onClicked(sender,sel,data)
    }

    @list.connect(SEL_RIGHTBUTTONPRESS){|sender,sel,data|
      @mpop.create
      item,index,hindex,dx,dy=@list.getItemAtCsr()
      if item 
        if  ! item.selected?
          @list.killSelection()
          item.select
        end
        x, y, buttons = getRoot().getCursorPosition()
        @mpop.popup(nil, x+10, y-4)
      end
    }
    
    
    
    #drag vvvvvvvvvvvvvvvvv
    @list.connect(SEL_DND_REQUEST){|sender,sel,data|
      # drag-src: daten an drop target ausliefern
      #mode,sidx,*idxRest = data
      #mode,*idxRest = data
      mode = data[:droptyp]
      #ret={} #[]
      #idxRest.each{|sidx|
      if sidx = data[:srcidx]
        data[:name],data[:contents] = getNameContents(sidx+1) #@rcFiles[sidx+1]
        @list.selectItem(sidx,false)
        if mode == DRAG_MOVE
          @rcFiles[sidx+1]=nil # [nil,""] 
          # puts "move deletes orig"
          #break #move only the first of selection
        end
      end
      #}
      refresh()
      data #ret
    }
    #drag ^^^^^^^^^^^^^^^^^^
    #drop vvvvvvvvvvvvvvvvv
    @list.connect(SEL_DND_MOTION){|sender,sel,data|
      # drop-tgt: action an drag-src liefern
      #tgtIndex,tgtItem,srcId = data
      dstIndex,dstItem,srcId = data[:dstidx],data[:dstitem],data[:srcid]
      #puts "#{@myId} MOTION #{srcId} #{tgtItem}"
      ret=DRAG_REJECT
      if dstItem and dstItem.empty?
        if srcId==@myId
          #puts "#{@myId} == #{srcId}"
          ret=DRAG_MOVE
        else
          #puts "#{@myId} != #{srcId}"
          ret=DRAG_COPY
        end
      end
      ret
    }
    
    @list.connect(SEL_DND_DROP){|sender,sel,data|
      # drop-tgt: drop ausfuehren
      #puts "SEL_DND_DROP"
      dsti,name,contents = data[:dstidx],data[:name],data[:contents]
      ret=false
      if contents
        # @list.selectItem(dsti,true)
        while dsti<16
          if @rcFiles[dsti+1].nil?
            if contents
              @rcFiles[dsti+1] = contents
              contents         = nil
            else
              ret=true
              break
            end
          end
          dsti+=1
        end
        #puts "next dsti=#{dsti}"
        dsti+=1
        refresh()
      else
      end
      ret # no more data
    }
    #drop ^^^^^^^^^^^^^^^^^^
    @rcFiles=Array.new(20)
    @totfree = (2048-4*16)*15/16
  end
  def create
    super
    app.addChore{ 
      @progress.hide
    }
  end
  def showFillRc(prc)
    unless @fillBar
      w=42
      h=16
      p2=FXProgressBar.new(self,nil,0, LAYOUT_FIX_WIDTH|LAYOUT_FIX_HEIGHT|LAYOUT_FIX_X|LAYOUT_FIX_Y,
                           @th9x.x+@th9x.width/2-w/2,@th9x.y+108-h/2,w,h,*[0]*4 ) 
      p2.barBGColor = FXRGB(0,100,50)
      p2.barColor = FXRGB(250,50,50)
      p2.create
      @fillBar=p2
    end
    @fillBar.progress=prc
  end
  def connect(sel,*args,&block)
    #if [SEL_LEFTBUTTONPRESS,
    #    SEL_LEFTBUTTONRELEASE,
    #    SEL_MOTION,
    #    SEL_CLICKED,
    #    SEL_DND_DROP, SEL_DND_REQUEST, SEL_DND_MOTION
    #   ].include?(sel)
    @userConnects[sel]=block
    #else
    #  @canvas.connect(sel,*args,&block)
    #end
  end
  def checkUserConnects(sender,sel,event)
    puts "def checkUserConnects(sender,#{sel},event)"
    sel=FXSELTYPE(sel)
    pp  @userConnects
    if @userConnects[sel]
      return @userConnects[sel].call(sender,sel,event)
    end
  end
  def getNameContents(fi)
    cont=@rcFiles[fi]
    return [nil,nil] if !cont
    name = Reader_V4.mbuf2name(cont).strip #.tr("\s","_")
    #name = cont[1,10].strip.tr("\s","_")
    [name,cont]
  end
  def getFiles
    (1..16).to_a.map{|fi|getNameContents(fi)}
  end
  #  def sysPd(cmd)
  #    pd = FXProgressDialog.new(self, "caption", "label",PROGRESSDIALOG_NORMAL|PROGRESSBAR_HORIZONTAL)
  #    pd.create
  #    pd.show
  #    sleep 0.1
  #    IO.popen(cmd){|f|
  #      while !f.eof
  #	s=f.gets
  #	puts s
  #	$log.appendText(s)
  #	pd.increment(10)
  #      end
  ##    }
  #  end
  def dudeBase()
    cmd  = ""
    cmd += @prefDialog.getVal(:AVRDUDEPATH)
    cmd += " -C " + @prefDialog.getVal(:AVRDUDECONF)
    cmd += " " + @prefDialog.getVal(:AVRDUDEPROGARGS)
  end
  
  def progress(tot=100)
    begin
      @progress.total=tot
      @progress.progress=1
      @progress.show
      yield
    ensure
      @progress.hide
      update
      #refresh()
    end
  end
  def progressInc(inc=1)
    @progress.progress+=inc
    @progress.progress = 1 if @progress.progress>=@progress.total
    app.runModalWhileEvents(nil) 
  end
  $origStderr = $stderr.dup
  def sysp(cmd)
    puts cmd
    $log.addColTxt(cmd+"\n","blue")
    progressInc(1)
    out=""
    ss=""
    IO.popen(cmd+" 2>&1"){|pipe|
      t0=Time.new
      while ! pipe.eof?
        s=""
        begin
          timeout(0.5){
            s+= (pipe.read(1)||"") while 1
          }
        rescue Timeout::Error
        end
        ss+=s
        out+=s
        if ss.count("\#")!=0 or ss=~/\n/
          
          $log.addColTxt(ss)#,"darkgreen")#
          $log.showEnd
          #STDOUT.flush
          yield ss if block_given? #makes runModalWhileEvents
          #app.runModalWhileEvents(nil) 
          ss=""
        end
      end
    }
    if $?.exitstatus != 0
      $log.addColTxt("system command failed exitstatus=#{$?.exitstatus}","red")
      $log.showEnd
      raise "system command failed:\n"+
        "#{out}\n\n"+
        "cmd=#{cmd}\n\n"+
        "exitstatus=#{$?.exitstatus}\n"
    end
  end
  def progressRead(ss)
    progressInc(ss.count("\#")/5.0)
  end
  def progressWrite(ss)
    if ! ss
      @cnt=@lcnt=0
      return
    end
    @cnt+=ss.count("\#")
    while @lcnt<@cnt
      progressInc(1); 
      if    @lcnt< 50;@lcnt+= 5
      elsif @lcnt<100;@lcnt+= 1
      else           ;@lcnt+= 5
      end
    end
  end
  
  def rcSave()
    progress(100){
      rm_f "eeTmp"
      progressInc
      if $opt_t
        #sysp(dudeBase + " -p 2343 -Ueeprom:r:eeTmp:r") {|ss| progressRead(ss)}
        cp "../eeprom.bin","eeTmp"
      else
        sysp(dudeBase + " -p m64 -Ueeprom:r:eeTmp:r") {|ss| progressRead(ss)}
      end
      eeReader=Reader_V4.new
      File.open("eeTmp","rb"){|f| eeReader.readEEprom(f); }
      progressInc
      
      eeWriter=Reader_V4.new
      eeWriter.format() 
      
      [0,18,19].each{|fi| #retain admin files (18,19 are unknown usage)
        fb,typ,sz= eeReader.readFile(fi)
        eeWriter.writeFile(fi,typ,fb) if fb.length!=0
      }
      (1..16).each{|idx|
        contents = @rcFiles[idx]
        eeWriter.writeFile(idx,2,contents) if contents and contents.length!=0
      }
      #eeWriter.info
      sleep 1
      progressInc
      
      File.open("eeTmp","wb"){|f| f.write(eeWriter.toBin) }
      
      progressWrite(nil)
      if $opt_t
        cp "eeTmp","../eeprom.bin"
        #sysp(dudeBase + " -p 2343 -Uflash:w:eeTmp:r") {|ss| progressWrite(ss)}
      else
        sysp(dudeBase + " -p m64 -Ueeprom:w:eeTmp:r") {|ss| progressWrite(ss)}
      end
      #showFillRc(eeWriter.usedBlks*100/(eeWriter.usedBlks+eeWriter.freeBlks))
      stat=eeWriter.getStat
      showFillRc(stat[:fillLev]*100)
    }
  end
  
  def rcLoad()
    progress(40) {
      #/etc/udev/rules.d:  PRODUCT=="USBasp",    MODE="0666", OPTIONS="last_rule"
      #sys("echo hello2;sleep 1; echo hello3; sleep 1")
      rm_f "eeTmp"
      progressInc
      
      if $opt_t
        #sysp dudeBase + " -p 2343 -Uflash:w:../eeprom.bin:r"
        #cnt,lcnt=0
        #sysp(dudeBase + " -p 2343 -Ueeprom:r:eeTmp:r") {|ss| progressRead(ss)}
        cp "../eeprom.bin","eeTmp"
      else
        sysp(dudeBase + " -p m64 -Ueeprom:r:eeTmp:r") {|ss| progressRead(ss)}
      end
      
      eeReader=Reader_V4.new
      File.open("eeTmp","rb"){|f| eeReader.readEEprom(f); }
      
      stat=eeReader.getStat
      showFillRc(stat[:fillLev]*100)
      @totfree = stat[:totUserBlks]*15
      
      @rcFiles=Array.new(20)
      eeReader.eachFile{|idx,name,contents|
        if idx==0
          @totfree -= ((contents.length+14)/15)*15 if contents
        end
        #name=name.strip.tr("\s","_")
        @rcFiles[idx] = contents # [name,contents]
        progressInc
      }
    }
    refresh
  end
  def refresh()
    used    = 0
    16.times{|i|
      name,contents=getNameContents(i+1) #@rcFiles[i+1]
      used += ((contents.length+14)/15)*15 if contents
      if name
        @rcItems[i].set($minidoc,name,contents.length)
      else
        @rcItems[i].set(nil,nil,nil)
      end
    }
    @usageLab.text="%d/%d (%d%%)"%[used,@totfree,used*100/@totfree]
    @list.update
  end
end
