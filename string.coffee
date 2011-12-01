### String processing and template utilities.
###
define 'mobone.string', (exports) ->
  
  String::startsWith = (s) -> @lastIndexOf(s, 0) is 0
  String::endsWith = (s) -> -1 isnt @indexOf s, @length - s.length
  String::toTitleCase = -> 
    @replace /\w\S*/g, (s) -> "#{s.charAt(0).toUpperCase()}#{s.substr(1).toLowerCase()}"
  
  
  # `decode()` a uri component and convert pluses to spaces.
  decode = (str) ->
    str = decodeURIComponent str
    str.replace /\+/g, ' '
    
  
  
  # `Processor` provides methods to `escape()`, `autolink()`, and 
  # `internationalise()` strings and a convenience method, `process()`,
  # to escape, autolink and internationalise in one go.
  class Processor
    
    # `autolink()` configuration.
    options:
      urlClass: 'url'
      hashtagClass: 'hashtag'
      usernameClass: 'username'
      listClass: 'badge'
      usernameUrlBase: '/'
      listUrlBase: '/'
      hashtagUrlBase: '/query?q=%23'
      suppressNoFollow: false
    
    # Not implemented yet, so passes through.
    internationalise: (s) -> s 
    
    # Turns urls, #hashtags, @usernames and @user/lists into links.
    autolink: (s) -> twttr.txt.autoLink s, @options
    
    # Escapes HTML entities.
    escape: (s) -> twttr.txt.htmlEscape s
      
    # Escape, autolink and internationalise.
    process: (s) -> @internationalise @autolink @escape s
    
    # Pass in `opts` to override the default `autolink()` configuration.
    constructor: (opts) -> _.extend(@options, opts) if opts?
    
  
  
  # `TemplateFactory` borrows `_.template`s templating logic (itself based
  # on John Resig's micro templating) and adds syntax to `escape` and `process`
  # interpolated strings.
  # 
  # The default syntax follows the ERB-style of `_.template` / and `eco`, with
  # one main addition of a tilda syntax `<%~ expression %>` to process a string
  # before interpolating:
  # 
  # * use `<% expression %>` to evaluate without printing the return value.
  # * use `<%= expression %>` to evaluate and print the escaped return value.
  # * use `<%~ expression %>` to evaluate and print the processed return value.
  # * use `<%- expression %>` to evaluate and print the return value without
  #   doing anything to it.
  #
  class TemplateFactory
    
    # Full dotted path that must resolve to an `escape()` function.
    escape: 'mobone.string.processor.escape'
    # Full dotted path that must resolve to a `process()` function.
    process: 'mobone.string.processor.process'
    
    syntax:
      # `<% expression %>`: evaluate without printing the return value.
      evaluate: /<%([\s\S]+?)%>/g, 
      # `<%- expression %>`: evaluate and print the return value.
      interpolate: /<%-([\s\S]+?)%>/g
      # `<%= expression %>`: evaluate, escape and print the return value.
      escape: /<%=([\s\S]+?)%>/g
      # `<%~ expression %>` evaluate, process and print the return value.
      process: /<%~([\s\S]+?)%>/g
    
    # `_.template` rewritten in `CoffeeScript` with additional replace calls to
    # match `syntax.escape` and `syntax.process`.
    template: (str, data) =>
      prefix = """var __p=[],print=function(){__p.push.apply(__p,arguments);};
        with(obj||{}){__p.push('"""
      suffix = "');}return __p.join('');"
      body = str.replace(
        /\\/g, "\\\\"
      ).replace(
        /'/g, "\\'"
      ).replace(
        @syntax.interpolate, 
        (match, code) -> 
          code = code.replace /\\'/g, "'"
          "',#{code},'"
      ).replace(
        @syntax.escape, 
        (match, code) => 
          code = code.replace /\\'/g, "'"
          "',#{@escape}(#{code}),'"
      ).replace(
        @syntax.process, 
        (match, code) => 
          code = code.replace /\\'/g, "'"
          "',#{@process}(#{code}),'"
      ).replace(
        @syntax.evaluate || null, 
        (match, code) -> 
          code = code.replace(/\\'/g, "'").replace(/[\r\n\t]/g, ' ')
          "');#{code}__p.push('"
      ).replace(
        /\r/g, '\\r'
      ).replace(
        /\n/g, '\\n'
      ).replace(
        /\t/g, '\\t'
      )
      tmpl = "#{prefix}#{body}#{suffix}"
      func = new Function 'obj', tmpl
      if data then func(data) else func
      
    
    # Convenience method to create a template from an element id.  Works nicely
    # with the pattern of including templates in `<script type="text/template" />`
    # elements with unique `id=""`s.
    templateFromId: (id, data) => 
      target = $ "##{id}"
      return @template target.html(), data if target.length > 0
      console.warn "Template ##{id} does not exist" if console? and console.warn?
      
    
    
    # Pass in `syntax` to override the default syntax.
    constructor: (syntax) -> _.extend(@syntax, syntax) if syntax?
    
  
  
  exports.decode = decode
  
  exports.Processor = Processor
  exports.TemplateFactory = TemplateFactory
  
  processor = new Processor
  exports.processor = processor
  
  factory = new TemplateFactory
  exports.template = factory.template
  exports.templateFromId = factory.templateFromId
  


