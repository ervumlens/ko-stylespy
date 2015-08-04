###
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
###
spylog = require('ko/logging').getLogger 'style-spy'
View = require 'stylespy/ui/view'

class SourceView extends View
	constructor: ->
		super
		@changeCount = 0
		@lastUpdateChange = -1
		@lastUpdateFirstLine = -1
		@registerOnUpdate()
		@registerOnModified()

	onUpdate: ->
		try
			#Modified or scrolled?
			needsUpdate =
				(@lastUpdateChange isnt @changeCount) or
				(@lastUpdateFirstLine isnt @scimoz.firstVisibleLine)
			if @active and needsUpdate
				#spylog.warn "SourceView::onUpdate"
				@updateLanguage()
				@styleAllVisible()
				@lastUpdateChange = @changeCount
				@lastUpdateFirstLine = @scimoz.firstVisibleLine
		finally
			@registerOnUpdate()
		false


	onModified: ->
		#spylog.warn "SourceView::onModified"
		++@changeCount
		false

	styleAllVisible: ->
		#TODO only style the visible columns
		firstLine = @scimoz.firstVisibleLine
		linesOnScreen = @scimoz.linesOnScreen
		lastLine = firstLine + linesOnScreen

		#Lines on screen reflects the size of the editor,
		#not the number of valid lines displayed. This means
		#firstVisibleLine + linesOnScreen is not necessarily a valid line.
		lastLine = @scimoz.lineCount if lastLine > @scimoz.lineCount

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

		#spylog.warn "SourceView: Styling #{firstLine} to #{lastLine}"

		line = firstLine
		while line < lastLine
			line = line + @styleLine line

	styleLine: (line) ->
		text = @lineText line

		return 1 unless text.length > 0

		#Return the number of lines processed.
		switch text[0]
			when '#' then @styleComment line
			when '^' then @styleContent line
			when '=' then @styleProperty line, text
			else @styleUnknown line

	styleComment: (line) ->
		firstPos = @scimoz.positionFromLine(line)
		lastPos = @scimoz.positionFromLine(line + 1)

		@scimoz.startStyling firstPos, 0
		@scimoz.setStyling lastPos - firstPos, View.STYLE_COMMENT
		1

	styleProperty: (line, text) ->
		@styleComment line

	styleUnknown: (line) ->
		@styleComment line

	styleContent: (line) ->
		#Return the number of lines styled/consumed

		firstPos = @scimoz.positionFromLine line
		lastPos = @scimoz.positionFromLine line + 1

		styleNumbers = @findStyleNumbersForLine line
		spylog.warn "SourceView::styleContent: StyleNumbers: #{styleNumbers.join(',')}"

		#Bad styles? Only style/consume the content line.
		if styleNumbers.length is 0
			@scimoz.startStyling firstPos, 0
			@scimoz.setStyling lastPos - firstPos, View.STYLE_COMMENT
			return 1

		#Style the content line...
		@scimoz.startStyling firstPos, 0
		@scimoz.setStyling 1, View.STYLE_COMMENT


		for i in [0 ... styleNumbers.length]
			@scimoz.setStyling 1, styleNumbers[i]

		if styleNumbers.length < (lastPos - firstPos)
			#Missing some styling. Slap that on now.
			missing = (lastPos - firstPos) - styleNumbers.length
			for i in [0 ... missing]
				@scimoz.setStyling 1, View.STYLE_COMMENT


		#Then whip through the style lines.
		firstPos = @scimoz.positionFromLine(line + 1)
		lastPos = @scimoz.positionFromLine(line + 3)

		@scimoz.startStyling firstPos, 0
		@scimoz.setStyling lastPos - firstPos, View.STYLE_STYLES

		3 #content line and two style lines

	findStyleNumbersForLine: (line, opts) ->
		lineCount = @scimoz.lineCount
		[style0, style1] = [null, null]

		if line + 2 < lineCount
			style0 = @lineText line + 1, false
			style1 = @lineText line + 2, false

		return [] unless @areStyleLines style0, style1
		@toStyleNumbers style0, style1, opts

	areStyleLines: (style0, style1) ->
		#Allow style 0 to be empty.
		(style0) and
		(style1) and
		(style0.trim().length is 0 || style0.indexOf(' ') is 0) and
		(style1.indexOf(' ') is 0)

	toStyleNumbers: (row0, row1, opts) ->
		#zip the rows, starting after the marker column
		lastStyle = 0
		styles = []
		style = 0
		styleText = ''
		#Calling trim() is too aggressive.
		#We just need to scrap EOL characters.
		row1 = row1.replace('\n', '')
		row1 = row1.replace('\r', '')
		for i in [1...row1.length]
			if row0[i]
				styleText = row0[i] + row1[i]
			else
				styleText = row1[i]

			noLeadChar = styleText[0].trim().length is 0
			inTab = styleText[1] is '\t' and noLeadChar
			inDot = styleText[1] is '.' and noLeadChar

			continue if opts?.ignoreTabs and inTab

			if inTab or inDot
				style = lastStyle
			else
				styleText = styleText.trim()
				style = Number.parseInt styleText
				style = View.STYLE_UNKNOWN if Number.isNaN style
				lastStyle = style
			styles.push style
		styles

	updateLanguage: ->
		#Find our language spec. If the language has changed, update the doc and scimoz.
		newLang = @findLanguage()
		if @lang isnt newLang
			#spylog.warn "Changing language from #{@lang} to #{newLang}"
			try
				@view.language = newLang
				@lang = newLang
			catch
				#revert
				@view.language = @lang

	lineText: (line, trimRight = true) ->
		start = @scimoz.positionFromLine line
		end = @scimoz.positionFromLine line + 1
		#spylog.warn "SourceView: lineText (start, end) = (#{start}, #{end})"
		text = @scimoz.getTextRange(start, end)
		text = text.trimRight() if trimRight
		text

	isValidLanguage: (lang) ->
		{Cc, Ci} = require 'chrome'
		langRegistry = Cc['@activestate.com/koLanguageRegistryService;1']
				 .getService(Ci.koILanguageRegistryService)

		countRef = new Object()
		namesRef = new Object()
		langRegistry.getLanguageNames namesRef, countRef
		lang in namesRef.value

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

		if not @isValidLanguage hitLang
			hitLang = @lang

		hitLang

module.exports = SourceView
