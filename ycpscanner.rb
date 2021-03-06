module Ycpscanner
  def next_token
#    $stderr.puts "next_token #{@in_comment}"

    if @scanner.empty?
      @scanner, @name, @lineno = @sstack.shift
#      $stderr.puts "[#{@scanner},#{@name}, #{@lineno}]: #{@sstack.size}"
      return [false, false] unless @scanner
      return next_token
    end

    if @in_comment
      m = @scanner.scan(%r{.*\*/})
      if m
	@in_comment = false
#	$stderr.puts "NOCOM #{m}"
      else
	m = @scanner.scan(%r{.*\n}) # read to eol
	@lineno += 1
	return next_token
      end
    end
    
#    puts "**** (#{@scanner.rest[0,16]})..." unless @scanner.rest.empty?
    case
      when @scanner.scan(/[ \t]+/)
	return next_token        # ignore space
	
      when m = @scanner.scan(%r{^#.*\n})
	@lineno += 1
	return next_token
	
      when m = @scanner.scan(%r{/\*})
#	$stderr.puts "COM:#{@lineno} #{m}"
        @in_comment = true
	return next_token

      when m = @scanner.scan(%r{//.*})
#	$stderr.puts "L:#{@lineno}"
	return next_token        # c++ style comment

      when m = @scanner.scan(%r{\d*\.\d+})
	return [:C_FLOAT, m.to_f]

      when m = @scanner.scan(%r{(0x|0X)([0123456789]|[abcdef]|[ABCDEF])+})
	return [:C_INTEGER, m.to_i]

      when m = @scanner.scan(%r{0[01234567]+})
	return [:C_INTEGER, m.to_i]

      when m = @scanner.scan(%r{(0|1)(b|B)})
	return [:C_INTEGER, m.to_i]
	
      when m = @scanner.scan(%r{\d+})
	return [:C_INTEGER, m.to_i]

      # string
      # FIXME: count embedded newlines
      when m = @scanner.scan(%r{\"([^\\\"]*)\"})
#	$stderr.puts "#{@lineno}:string(#{m})"
	return [:C_STRING, @scanner[1]]

      # string with embedded backslash
      # FIXME: count embedded newlines
      when m = @scanner.scan(%r{\"(([^\\\"])|(\\.)+|(\\\n)+)*\"})
#	$stderr.puts "#{@lineno}:string(#{m})"
	return [:C_STRING, @scanner[1]]

      when m = @scanner.scan(%r{#\[(.*)\]})
	return [:C_BYTEBLOCK, @scanner[1]]
      
      when m = @scanner.scan(%r{(\.\w+)+})
	return [:C_PATH, m]
      when m = @scanner.scan(%r{\`\w+})
	return [:C_SYMBOL, m]
      when m = @scanner.scan(%r{_\(})
#	$stderr.puts "#{@name}:#{@lineno}"
	return [:I18N, m]
      when m = @scanner.scan(%r{\$\[})
	return [:MAPEXPR, m]
      when m = @scanner.scan(%r{==})
	return [:RELOP, m]
      when m = @scanner.scan(%r{!=})
	return [:RELOP, m]
      when m = @scanner.scan(%r{\<=})
	return [:RELOP, m]
      when m = @scanner.scan(%r{\>=})
	return [:RELOP, m]
      when m = @scanner.scan(%r{\<\>})
	return [:RELOP, m]
      when m = @scanner.scan(%r{\<\<})
	return [:LEFT, m]
      when m = @scanner.scan(%r{\>\>})  # also used for list/map types
	return [:RIGHT, m]
      when m = @scanner.scan(%r{\&\&})  # do not collapse to BOOLOP for assoc
	return [:AND, m]
      when m = @scanner.scan(%r{\|\|})
	return [:OR, m]
      when m = @scanner.scan(%r{\]:})
	return [:CLOSEBRACKET, m]
      when m = @scanner.scan(%r{list::reduce}) # /usr/share/YaST2/include/partitioning/ep-settings.ycp:37
	return [:SYMBOL, m]
      when m = @scanner.scan(%r{float::ceil}) # /usr/share/YaST2/include/partitioning/ep-hd-dialogs.ycp:105
	return [:SYMBOL, m]
      when m = @scanner.scan(%r{\`\`\{})
	return [:QUOTED_BLOCK, m]
      when m = @scanner.scan(%r{\`\`\(})
	return [:QUOTED_EXPRESSION, m]

      when m = @scanner.scan(%r{(\w+)?(::\w+)+})
	return [:SYMBOL, m]
	
      when m = @scanner.scan(%r{\w+})
	case m
	when "false": return [:C_BOOLEAN, false]
	when "true": return [:C_BOOLEAN, true]
	when "empty": return [:EMPTY, m]
	  
	when "define": return [:DEFINE, m]
	when "undefine": return [:UNDEFINE, m]
	when "import": return [:IMPORT, m]
	when "export": return [:EXPORT, m]
	when "include": return [:INCLUDE, m]
	when "static": return [:STATIC, m]
	when "extern": return [:EXTERN, m]
	when "global": return [:GLOBAL, m]
	when "module": return [:MODULE, m]
	when "const": return [:CONST, m]
	when "typedef": return [:TYPEDEF, m]
	when "textdomain": return [:TEXTDOMAIN, m]
	  
	when "return": return [:RETURN, m]
  	when "continue": return [:CONTINUE, m]
	when "break": return [:BREAK, m]
	when "if": return [:IF, m]
	when "else": return [:ELSE, m]
	when "is": return [:IS, m]
	when "do": return [:DO, m]
	when "while": return [:WHILE, m]
	when "repeat": return [:REPEAT, m]
	when "until": return [:UNTIL, m]
	when "switch": return [:SWITCH, m]
	when "case": return [:CASE, m]
	when "default": return [:DEFAULT, m]

	when "list": return [:LIST, m]
	when "map": return [:MAP, m]
	when "block": return [:BLOCK, m]
	  
	when "any": return [:C_TYPE, m]
	when "void": return [:C_TYPE, m]
	when "boolean": return [:C_TYPE, m]
	when "integer": return [:C_TYPE, m]
	when "float": return [:C_TYPE, m]
	when "string": return [:C_TYPE, m]
	when "locale": return [:C_TYPE, m]
	when "byteblock": return [:C_TYPE, m]
	when "symbol": return [:C_TYPE, m]
	when "term": return [:C_TYPE, m]
	when "path": return [:C_TYPE, m]
	else
	  t = @symbols[m]                  # typedef'd ?
	  return( [t, m] ) if t
	  return( [:SYMBOL, m] )
	end # case m
	
      when m = @scanner.scan(/\f/)         # embedded ^L
        return next_token
	
      when m = @scanner.scan(/./)
#	$stderr.puts "RETURN <#{m}>"
        return [m, m]

      when m = @scanner.scan(%r{(\n)+})
	@lineno += m.size
	return next_token        # ignore newlines

    end # case
    raise "**** Unrecognized(#{@scanner.rest[0]})..." unless @scanner.rest.empty?
    return [false, false]
  end

  def parse( file )
    open file
    do_parse
  end
  
  def on_error(*args)
    $stderr.puts "Err #{@name}@#{@lineno}: args=#{args.inspect}"
    raise "Parse error"
  end

end # module
