=begin
= cstruct.rb

cstruct.rb provides a ruby module which allows  access to structured 
binary data in a decent way.
The data-structures are described in a c-style manner, access is done with
ruby methods.

== Vesion
  $Id: cstruct.rb,v 1.4 2002/03/18 23:39:31 thus Exp $

== Example
require 'cstruct'

CStruct.alignment=1

CStruct.defStruct "TheCType",<<-"END_TYP"
  uint8_t 	elt1[2];
  uint8_t 	elt2:3;
  uint8_t 	elt3:4;
  uint16_t 	elt4;
END_TYP

cVar        = CStruct::TheCType.new
cVar.elt1[0]= 0x48
cVar.elt1[1]= 0x45
cVar.elt2   = 0x4
cVar.elt3   = 0xd
cVar.elt4   = 0x4f4c #0x4548

puts          cVar
p             cVar.toBin
File.open("test","w"){|f| cVar.write(f)}

== CStruct module
CStruct provides some methods which let you define some data structures
(CStruct.defStruct and CStruct.defBaseT).
The definitions are parsed from ascii-input strings.
The definition format is very similar to a simple C-structure definition.
The main goal of this module was to give access to some binary data files
which were written by a c-program. Your sole job should be to copy the 
structure-definitions from the c-header-files into a ruby script,
give it to CStruct.defStruct as a string and then you can read or write
the binary data.

The method CStruct.defStruct defines a ruby class in the module CStruct
with a given class name (first char should be uppercase, spaces are 
replaced by underscore).
You can instantiate such a class with CStruct::TheCType.new() and then 
access each member by the appropriate member functions.

The data-types of the structure elements can be either base types or
structure types or arrays of them.

Both base types and structure types must be defined before usage.

If the data structure contains holes caused by the alignment (default = 4)
then dummy members are generated automatically.


=== methods
--- CStruct.defBaseT(name,sizeof,signed)
    Define a base-type. the 6-posix inttypes int8_t..uint32_t are already
    predefined in the module CStruct.
    parameter sizeof can be 1,2,4
    parameter signed can be true or false

--- CStruct.defStruct
    Define a structured type with means of an ascii-string.
    Line by line.

--- CStruct.alignment=
    Set alignment of whole structure definitions

=== methods of generated c-type-classes



--- fromBin
    convert a binary string representation into the data structure 

--- read
    like fromBin, but read binary data from a file instead of a string

--- toBin
    convert the whole data structure into a binary representation and
    return this as a string

--- write
    like toBin, but write binary data to a file

--- sizeof
    return the size of the data-structure. This method exists both as a
    class-method an an object-method

--- 'userelement'=
    this method exists for each Element of the data structure and lets
    you write the appropriate data member

--- 'userelement'
    this method exists for each Element of the data structure and lets
    you read the appropriate data member

--- to_s
    return a string representation of the whole data structure.
    This is used by puts


== Todo
  * support 'strict alignMent'
  * support big and little endianess
  * float-support
  * support symbolic array-sizes
  * copy whole structures
  * generic access to the data by string keys --> workaround: use eval

== Bugs

== References
== License
You can use/re-distribute/change CStruct under Rubys License or GPL.
== Author
  Thomas Husterer 
  s-t.husterer@t-online.de

=end

module CStruct
  @@alignment=4
  def CStruct.alignment=(align) @@alignment= align                        end
  def CStruct.alignment()@@alignment                                      end
  class CStructBase
    attr_reader :offset
    attr_reader :hidden
    def initialize(offset)   @offset=offset; @membn=[]; @membv={}; @hidden=false; end
    def hide() @hidden=true; end
    def each() @membn.each{|n| yield n,@membv[n].get,@membv[n].obj} end
    def child(n)      @membv[n]; end
    def obj()            self;                                            end
    def get()            self;                                            end
    def sizeof()         self.class.sizeof                                end
    def toBin() ret= ""; @membn.each { |n|; ret += @membv[n].toBin}; ret; end
    def fromBin(b,i=0)   @membn.each { |n|; i=@membv[n].fromBin(b,i)}; i; end
    def read(f)          fromBin(f.read(sizeof()))                        end
    def write(f)         f.write(toBin)                                   end
    def to_s()           to_sInternal(0)[0]                               end
    def to_sInternal(ofs,nest=0)
      s=nest>0 ? "\n" : ""; 
      @membn.each { |n|;
        #ofs==@membv[n].offset or raise " bad offset #{ofs} != #{@membv[n].offset}"
        #s+=sprintf("%3d ",@membv[n].offset)
        x,ofs = @membv[n].to_sInternal(ofs,nest+1)
        unless @membv[n].hidden
          s+=sprintf("%3d ",@membv[n].offset)+("    "*nest) + "#{n}\t= "+x
        end
      }; 
      [s+"\n",ofs]
    end
  end
  class BaseT < CStructBase
  end

  class BitFld < CStructBase
    def initialize(refobj,bits,pos,signed)#typ)
      super(refobj.offset)
      #printf "signed = #{signed.inspect}\n"
      #raise
      @refobj,@bits,@pos = refobj,bits,pos
      @signed =  signed #typ !~ /^u/
    end
    def each()                                   end
    def to_sInternal(ofs,nest=0) 
      [sprintf("0x%x %d (%s.%d:%d)\n",get(),get(),@refobj.class.to_s[9..-1],@pos,@bits),ofs]         
    end
    def set(v)   
      #raise "todo";                   
      msk=((1<<@bits)-1)
      x = @refobj.get()
      #printf "msk=%x old x=%x #{@signed}\n",msk,x
      x = (x & ~(msk << @pos)) | ((v & msk) << @pos)
      @refobj.set(x)
    end
    def get()    
      msk=((1<<@bits)-1)
      ret  = (@refobj.get()>>@pos) & msk
      ret -= (1<<@bits)  if @signed and (ret & ((1<<@bits-1)) != 0)
      ret
    end
    def toBin()                 ""               end
    def inspect()               get().inspect()  end
    def to_s()                  get().to_s();    end
    def to_i()                  get();           end
    def fromBin(bin,pos)        pos;             end
  end
  class CArray < CStructBase
    def initialize(offset,n,typ) 
      super(offset);  
      n.times{|j|  i=j.to_s
        @membn.push i; 
        @membv[i]  = typ.new(offset);
        offset     += @membv[i].sizeof()
      }
    end
    def []=(i,v) @membv[i.to_s].set(v)                                   end
    def [](i)    @membv[i.to_s].get()                                    end
  end
  class CString < BaseT
    def initialize(offset,n) @offset=offset; @strlen=n                      end
    def sizeof()            @strlen                                      end
    def CString.granu()     1                                            end
    def to_sInternal(ofs,nest=0) 
        [sprintf("%s (%s)\n",@value.inspect,self.class.to_s[9..-1]),ofs+@strlen]             end
      def set(v)    @value = v;                                          end
      def get()     @value;                                              end
      def toBin()   [@value].pack "a#{@strlen}";                         end
      def fromBin(bin,pos)
        @value,=bin[pos,@strlen].unpack("a#{@strlen}"); @strlen + pos 
      end
  end


  def CStruct.cT2rbT(n)  n[0]=n[0,1].upcase; n.gsub! /\s+/,"_";  n        end
  def CStruct.defBaseT(name,sizeof,signed)
    fmt=signed ? ["","c","s","","l"][sizeof] : ["","C","S","","L"][sizeof]
    cT2rbT name
    d = <<-"END"
    class #{name} < BaseT
      def initialize(offset) @offset=offset; @value=0                        end
      def each()                                                          end
      def #{name}.signed()    #{signed}                                   end
      def #{name}.sizeof()    #{sizeof}                                   end
      def #{name}.granu()     #{sizeof}                                   end
      def to_sInternal(ofs,nest=0) 
        [sprintf("0x%x %d (%s)\n",@value,@value,self.class.to_s[9..-1]),ofs+#{sizeof}]          end
      def set(v)    @value = v;                                           end
      def get()     @value;                                               end
      def toBin()   [@value].pack "#{fmt}";                               end
      def inspect()   @value.inspect()                          end
      def to_s()    @value.to_s();                          end
      def to_i()    @value;                          end
      def fromBin(bin,pos)
        @value,=bin[pos,sizeof].unpack "#{fmt}"; #{sizeof} + pos 
      end
    end
    END
    CStruct.module_eval d,__FILE__+" #1",0
  end
  def CStruct.defStruct(tname,cdef)  DefStruct.new(tname,cdef)            end
  class DefStruct
    def initialize(tname,cdef)
      @init="\n"
      @defs="\n"
      @pos=0
      @granu=0
      @bitFld=nil; @bitFldCnt=0
      cdef.each { |l|
        l.sub! /(\#|\/\/).*$/,""   #remove comments
        l.sub! /;\s*$/,""          #remove ';' at the end
        l.gsub! /\s*,\s*/,","      #remove space around ','
        l.strip!                   #remove leading and trailing spaces
        l.gsub! /\s+/," "          #subst group of spaces into single spaces
        case l
        when /^[{}]?\s*$/
        when /^(.+)\s(\w+)\[\s*(\d+)\s*\]/  #char name[10]
          typ,name,cnt = $1,$2,$3.to_i
          finBitFld
          if(typ=="char")
            addStringMember(name,cnt)
          else
            addArrayMember(typ,name,cnt)
          end
        when /^(.+)\s(\S+)/
          typ,names = $1,$2
          #names.split(/,/).each{|n| addMember(typ,n)}
          names.split(/,/).each{|n| 
            if n=~/(\w+):(\d+)/
              n,bits = $1,$2.to_i
              addBitFld(typ,n,bits)
            else
              finBitFld
              addMember(typ,n)
            end
          }
        else
          raise "line not recognized '#{l}'"
        end
      }
      finBitFld
      CStruct.cT2rbT(tname)
      d=<<-"END"    
      class #{tname} < CStructBase
        def #{tname}.sizeof()  #{@pos}  
        end
        def #{tname}.granu() #{@granu}
        end
        def initialize(offset=0)    
          super(offset);   
          #{@init}; 
        end
        #{@defs}
      end
      END
      #puts d
      CStruct.module_eval d,__FILE__+" #1",0
      #puts "#{tname}.sizeof() = #{@pos}"
    end

    def doAlign(typ)
      g=[CStruct.module_eval("#{typ}.granu"),CStruct.alignment].min
      @granu=[@granu,g].max
      while (@pos % g) != 0
        @init += <<-"END"
        @membn.push "gap_#{@pos}"
        @membv["gap_#{@pos}"]=Uint8_t.new(#{@pos}+offset)
        END
        @pos+=1
      end
    end
    def addStringMember(name,cnt)
      @init += <<-"END"
      @membn.push "#{name}"
      @membv["#{name}"]=CString.new(#{@pos}+offset,#{cnt})
        END
      @defs += <<-"END"
      def #{name} ()
        @membv["#{name}"].get()
      end
      END
      @pos+=cnt
    end

    def addArrayMember(typ,name,cnt)
      CStruct.cT2rbT(typ)
      doAlign(typ)
      @init += <<-"END"
      @membn.push "#{name}"
      @membv["#{name}"]=CArray.new(#{@pos}+offset,#{cnt},#{typ})
        END
      @defs += <<-"END"
      def #{name} ()
        @membv["#{name}"]
      end
      END
      @pos+=CStruct.module_eval("#{typ}.sizeof")*cnt
    end
    def addMember(typ,name)
      #puts "addMember(#{typ},#{name})"
      CStruct.cT2rbT(typ)
      doAlign(typ)
      @init += <<-"END"
      @membn.push "#{name}"
      @membv["#{name}"]=#{typ}.new(#{@pos}+offset)
      END
      @defs += <<-"END"
      def #{name}= (v)  @membv["#{name}"].set(v)    end
      def #{name} ()    @membv["#{name}"].get()     end
      END
      @pos+=CStruct.module_eval("#{typ}.sizeof")
    end
    def finBitFld
      return unless @bitFld
      # pp @bitFld
      pos,typ=@bitFld.shift
      @bitFldCnt+=1
      refname="__bf#{@bitFldCnt}"
      addMember(typ,refname)
      @init += <<-"END"
        @membv["#{refname}"].hide()
      END
      @bitFld.each{|name,bits,pos,typ|
        signed= CStruct.module_eval("#{typ}.signed")
        @init += <<-"END"
          @membn.push "#{name}"
          @membv["#{name}"]=BitFld.new(@membv["#{refname}"],#{bits},#{pos},#{signed})
        END
        @defs += <<-"END"
         def #{name}= (v)  @membv["#{name}"].set(v)    end
         def #{name} ()    @membv["#{name}"].get()     end
        END
      }

      @bitFld=nil
    end
    def addBitFld(typ,n,bits)
      #puts "def addBitFld(#{typ},#{n},#{bits})"
      CStruct.cT2rbT(typ)

      #fehlt: byte-überlappende felder, signed,unsigned
      finBitFld if @bitFld and (pos=@bitFld[0][0])+bits > 8
      @bitFld=[[pos=0,typ]] if !@bitFld
      @bitFld.push( [n,bits,pos,typ ])
      @bitFld[0][0] = pos + bits
    end
  end
  defBaseT("uint32_t",4,false)
  defBaseT("uint16_t",2,false)
  defBaseT("uint8_t", 1,false)
  defBaseT("bool",    1,false)
  defBaseT("int32_t", 4,true)
  defBaseT("int16_t", 2,true)
  defBaseT("int8_t" , 1,true)
  defBaseT("char" ,   1,true)
end

