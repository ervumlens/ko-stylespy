xtk.include("domutils");

gDoc = null
gView = null
watcher = null
spylog = ko.logging.getLogger 'style-spy'
style = require 'stylespy/style'

StyleSpyOnBlur = ->
StyleSpyOnFocus = ->

class StyleWatcher
	constructor: (@view, @doc) ->
		@handler = (args...) => @onModified(args...)
		@scimoz = @view.scimoz
		@updateLanguage()
		@view.addModifiedHandler @handler, {}, 0xFFFF, 0x03

	release: ->
		@view.removeModifiedHandler @handler

	onModified: (position, modType, text, len, linesAdded, line, foldNow, foldThen) ->
		spylog.warn "Modified: #{position}, #{modType}, #{text}, #{len}, #{linesAdded}, #{line}"
		@updateLanguage()
		@styleVisible()

	styleVisible: ->
		#TODO only style the visible columns
		firstLine = @scimoz.firstVisibleLine
		linesOnScreen = @scimoz.linesOnScreen

		firstText = @findNextLineIndex(firstLine)

		#Nothing to style on the screen
		return if firstLine + linesOnScreen < firstText

		lastLine = firstLine + linesOnScreen
		firstLine = firstText if firstText > firstLine

		#firstPos = @scimoz.positionFromLine(firstLine)
		#lastPos = @scimoz.positionFromLine(lastLine)
		#@scimoz.startStyling firstPos, 0
		#@scimoz.setStyling(lastPos - firstPos, 5)

		line = firstLine
		while line < lastLine
			nextLine = @findNextLineIndex(line)
			spylog.warn "Styling line #{nextLine} (#{@lineText nextLine})"
			line = @styleLine nextLine

		#@scimoz.colourise 0, 100

	styleLine: (line) ->
		result = @parseStyleLine line
		styleNumbers = @toStyleNumbers result.allText[1], result.allText[2]
		spylog.warn "StyleNumbers: #{styleNumbers.join(',')}"
		firstPos = @scimoz.positionFromLine(line)

		@scimoz.startStyling firstPos + 1, 0
		for i in [0...styleNumbers.length]
			@scimoz.setStyling 1, styleNumbers[i]
		result.line

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
				style = 0 if Number.isNaN style
				lastStyle = style
			styles.push style
		styles

	parseStyleLine: (line) ->
		styleRx = /^\s(.+)$/
		textRx = /^\^(.+)$/
		lineCount = @scimoz.lineCount
		allText = [@lineText line]
		styleCount = 0
		curLine = line + 1
		for line in [curLine...lineCount]
			text = @lineText line, false
			text = text.slice(0, -1)
			if styleRx.test text
				allText.push text.trimRight()
				break if ++styleCount is 2
			#implicitly skip comment lines

		spylog.warn "parseStyleLine: #{allText.join('/')}"

		{line, allText}

	updateLanguage: ->
		#Find our language spec. If the language has changed, update the doc and scimoz.
		newLang = @findLanguage()
		if @lang isnt newLang
			spylog.warn "Changing language from #{@lang} to #{newLang}"
			@lang = newLang
			@doc.language = @lang
			@view.language = @lang
			#@view.initWithBuffer @doc.buffer, @doc.language

			#@doc.docSettingsMgr.applyDocumentSettingsToView @view
			#langObj = @doc.languageObj
			#@view.languageObj = langObj
			#lexer = langObj.getLanguageService Components.interfaces.koILexerLanguageService
			#@view.koDoc.docSettingsMgr.applyViewSettingsToDocument @view
			#@view.koDoc.language = @lang
			#if lexer
			#	spylog.warn "Found lexer for #{@lang}"
			#	lexer.setCurrent @scimoz
			#else
			#	spylog.warn "No lexer for #{@lang}"

	lineText: (line, trimRight = true) ->
		start = @scimoz.positionFromLine line
		end = @scimoz.positionFromLine line + 1
		text = @scimoz.text.substr(start, end - start)
		text = text.trimRight() if trimRight
		text

	findFirstLineIndex: ->
		@findNextLineIndex 0

	findNextLineIndex: (startingLine) ->
		lineRx = /^\^/
		lineCount = @scimoz.lineCount
		for line in [startingLine...lineCount]
			return line if lineRx.test @lineText line

		return lineCount

	findLanguage: ->
		hitRx = /^~language\s+(.+)$/

		quitHere = @findFirstLineIndex()
		lineCount = @scimoz.lineCount

		hitLang = @lang
		for line in [0...lineCount]
			text = @lineText line
			match = hitRx.exec text
			if match
				hitLang = match[1]
				spylog.warn "Found language #{hitLang} in `#{text}`"
				break
			else if line is quitHere
				spylog.warn "No language found before line #{quitHere + 1}"
				break
			else
				spylog.warn "No language found in `#{text}`"

		hitLang

StyleSpyOnLoad = ->
	try
		scintillaOverlayOnLoad()
		gView = document.getElementById "view"
		documentService = Components.classes["@activestate.com/koDocumentService;1"].getService()
		gDoc = documentService.createUntitledDocument "Text"
		gDoc.addReference()

		if window.arguments && window.arguments[0]
			opts = window.arguments[0]
			if 'view' of opts
				done = (content) -> gDoc.buffer = content
				progress = ko.dialogs.progress
				style.extractAllLineStyles opts.view, progress, done
			else if 'buffer' of opts
				gDoc.buffer = opts.buffer

		gView.initWithBuffer gDoc.buffer, gDoc.language
		#gDoc.addView gView
		#gDoc.addScimoz gView.scimoz
		#gView.koDoc = gDoc

		watcher = new StyleWatcher(gView, gDoc)

		if navigator.platform.match /^Mac/
			#Bug 96209, bug 99277 - hack around scintilla display problems on the mac.
			setTimeout (-> gView.scintilla.setAttribute "flex", "2"), 1
	catch e
		spylog.error e

StyleSpyOnUnload = ->
	watcher.release()
    #The "close" method ensures the scintilla view is properly cleaned up.
	#gDoc.releaseScimoz gView.scimoz
	#gDoc.releaseView gView
	#gView.koDoc = null
	gView.close()
	gDoc.releaseReference()
	scintillaOverlayOnUnload()
