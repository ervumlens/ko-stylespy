###
License
###
#The view-related bits are mostly lifted from Komodo's tail.js

STYLE_UNKNOWN = 0
STYLE_COMMENT = 2
STYLE_STYLES = 2

xtk.include 'domutils'

gDoc = null
gView = null
watcher = null
spylog = ko.logging.getLogger 'style-spy'
style = require 'stylespy/style'

StyleSpyOnBlur = ->
StyleSpyOnFocus = ->

class StyleWatcher
	constructor: (@view, @doc) ->
		@handler = (args...) => @onUpdate(args...)
		@scimoz = @view.scimoz
		@updateLanguage()

		#Clear all styles first. This does nothing but it makes me feel better.
		@scimoz.startStyling 0, 0
		@scimoz.setStyling @scimoz.textLength, STYLE_COMMENT
		@scimoz.colourise 0, -1

		@register()

	release: ->

	register: ->
		@view.registerUpdateUICallback @handler

	onUpdate: ->
		try
			@updateLanguage()
			@styleAllVisible()
		finally
			#We're all updated now. Register ourself again for the next change.
			@register()

	styleAllVisible: ->
		#TODO only style the visible columns
		firstLine = @scimoz.firstVisibleLine
		linesOnScreen = @scimoz.linesOnScreen
		lastLine = firstLine + linesOnScreen

		if firstLine >= 3
			#skip back 3 lines to prevent straggling
			#style lines from looking funny.
			firstLine -= 3

		if lastLine + 3 < @scimoz.lineCount
			#skip ahead 3 for the same reason.
			lastLine += 3

		if lastLine + 3 < @scimoz.lineCount
			#skip ahead 3 more to avoid onUpdateUI's flicker problem.
			lastLine += 3

		#spylog.warn "Styling #{firstLine} to #{lastLine}"

		line = firstLine
		while line < lastLine
			line = line + @styleLine line

	styleLine: (line) ->
		text = @lineText line

		return 1 unless text.length > 0

		consumed = 1

		switch text[0]
			when '#' then @styleComment line
			when '^' then consumed = @styleContent line
			when '=' then @styleProperty line, text
			else @styleUnknown line

		consumed

	styleComment: (line) ->
		firstPos = @scimoz.positionFromLine(line)
		lastPos = @scimoz.positionFromLine(line + 1)

		@scimoz.startStyling firstPos, 0
		@scimoz.setStyling lastPos - firstPos, STYLE_COMMENT

	styleProperty: (line, text) ->
		@styleComment line

	styleUnknown: (line) ->
		@styleComment line

	styleContent: (line) ->
		#Return the number of lines styled/consumed
		style0 = @lineText line + 1, false
		style1 = @lineText line + 2, false

		#Bad styles? Only style/consume the content line.
		if not @areStyleLines style0, style1
			firstPos = @scimoz.positionFromLine line
			lastPos = @scimoz.positionFromLine line + 1
			@scimoz.startStyling firstPos, 0
			@scimoz.setStyling lastPos - firstPos, STYLE_COMMENT
			return 1

		styleNumbers = @toStyleNumbers style0, style1
		#spylog.warn "StyleNumbers: #{styleNumbers.join(',')}"
		firstPos = @scimoz.positionFromLine(line)

		#Style the content line...
		@scimoz.startStyling firstPos, 0
		@scimoz.setStyling 1, STYLE_COMMENT

		for i in [0 ... styleNumbers.length]
			@scimoz.setStyling 1, styleNumbers[i]

		#Then whip through the style lines.
		firstPos = @scimoz.positionFromLine(line + 1)
		lastPos = @scimoz.positionFromLine(line + 3)

		@scimoz.startStyling firstPos, 0
		@scimoz.setStyling lastPos - firstPos, STYLE_STYLES

		3 #content line and two style lines

	areStyleLines: (style0, style1) ->
		#Allow style 0 to be empty.
		(style0.trim().length is 0 || style0.indexOf(' ') is 0) && (style1.indexOf(' ') is 0)

	toStyleNumbers: (row0, row1) ->
		#zip the rows, starting after the marker column
		lastStyle = 0
		styles = []
		style = 0
		for i in [1...row1.length]
			if row0[i]
				style = (row0[i] + row1[i]).trim()
			else
				style = row1[i]

			if style is '.'
				style = lastStyle
			else
				style = Number.parseInt style
				style = STYLE_UNKNOWN if Number.isNaN style
				lastStyle = style
			styles.push style
		styles

	updateLanguage: ->
		#Find our language spec. If the language has changed, update the doc and scimoz.
		newLang = @findLanguage()
		if @lang isnt newLang
			#spylog.warn "Changing language from #{@lang} to #{newLang}"
			try
				@doc.language = newLang
				@view.language = newLang
				@lang = newLang
			catch
				#revert
				@doc.language = @lang
				@view.language = @lang

	lineText: (line, trimRight = true) ->
		start = @scimoz.positionFromLine line
		end = @scimoz.positionFromLine line + 1
		text = @scimoz.text.substr(start, end - start)
		text = text.trimRight() if trimRight
		text

	findLanguage: ->
		hitRx = /^=language\s+(.+)$/

		lineCount = @scimoz.lineCount

		hitLang = @lang
		for line in [0...lineCount]
			text = @lineText line
			match = hitRx.exec text
			if match
				hitLang = match[1]
				break
			else if text.indexOf('^') is 0
				break

		hitLang


appendToStyleBuffer = (buffer, source) ->
	switch source.type
		when 'view'
			done = (content) -> buffer.push content
			progress = ko.dialogs.progress
			style.extractAllLineStyles source.content, progress, done
		when 'buffer'
			buffer.push source.content
		when 'uri'
			fileService = Components.classes['@activestate.com/koFileService;1'].createInstance(Components.interfaces.koIFileService)
			file = fileService.getFileFromURINoCache source.content
			file.open 'r'
			try
				buffer.push file.readfile()
			finally
				file.close()

StyleSpyOnLoad = ->
	try
		scintillaOverlayOnLoad()
		gView = document.getElementById 'view'
		documentService = Components.classes['@activestate.com/koDocumentService;1'].getService()

		gDoc = documentService.createUntitledDocument 'Text'

		#The output is a composite from potentially multiple sites.
		#Pull everything together in a local buffer before
		#passing on to the doc.
		buffer = []

		if window.arguments and window.arguments.length > 0
			opts = window.arguments[0]
			if opts.sources
				appendToStyleBuffer(buffer, source) for source in opts.sources
			else if opts.source
				appendToStyleBuffer buffer, opts.source

		gDoc.buffer = buffer.join('\n');

		gDoc.addReference()
		gView.initWithBuffer gDoc.buffer, gDoc.language

		watcher = new StyleWatcher(gView, gDoc)

		if navigator.platform.match /^Mac/
			#Bug 96209, bug 99277 - hack around scintilla display problems on the mac.
			setTimeout (-> gView.scintilla.setAttribute 'flex', '2'), 1
	catch e
		spylog.error e

StyleSpyOnUnload = ->
	watcher.release() if watcher
    #The "close" method ensures the scintilla view is properly cleaned up.
	gView.close() if gView
	gDoc.releaseReference() if gDoc
	scintillaOverlayOnUnload()
