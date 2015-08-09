###
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
###
spylog 	= require('ko/logging').getLogger 'style-spy'
View 	= require 'stylespy/ui/view'
EolMode = require 'stylespy/eol-mode'
LineType= require 'stylespy/line-type'
Stylist = require 'stylespy/ui/stylist'

class SourceView extends View
	constructor: ->
		super
		@changeCount = 0
		@lastUpdateChange = -1
		@lastUpdateFirstLine = -1
		@registerOnUpdate()
		@registerOnModified()
		@stylist = new Stylist @,
			stylingOffset: 1
			alwaysClearIndicators: true

	onUpdate: ->
		try
			#Modified or scrolled?
			needsUpdate =
				(@lastUpdateChange isnt @changeCount) or
				(@lastUpdateFirstLine isnt @scimoz.firstVisibleLine)
			if @active and needsUpdate
				#spylog.warn "SourceView::onUpdate"
				@updateRootProperties()
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

	localLineToSourceLine: (line) ->
		line

	styleAllVisible: ->
		@stylist.styleAllVisible()

	classifyLine: (line) ->
		start = @scimoz.positionFromLine line
		switch @scimoz.getCharAt start
			when 35 then LineType.COMMENT	# "#"
			when 61 then LineType.PROPERTY	# "="
			when 94 then LineType.CONTENT	# "^"
			when 32 then LineType.STYLE		# " "
			when 42 then LineType.INDICATOR	# "*"
			else LineType.UNKNOWN

	findStyleNumbersForLine: (line, length, opts) ->
		if not opts
			opts = ignoreTabs: false, throwOnBadStyles: true

		lineCount = @scimoz.lineCount
		[style0, style1] = [null, null]

		if line + 2 < lineCount
			style0 = @lineText line + 1, false
			style1 = @lineText line + 2, false

		styleNumbers = if @areStyleLines style0, style1
			@zipColumnNumbers style0, style1, opts
		else if opts?.throwOnBadStyles
			throw new Exception "Bad styles for source line #{line}"
		else
			[]

		if styleNumbers.length < length
			#missing some values, just fill them in with whatever
			difference = length - styleNumbers.length
			for i in [0 ... difference]
				styleNumbers.push View.STYLE_UNKNOWN

		styleNumbers

	areStyleLines: (style0, style1) ->
		#Allow style 0 to be empty.
		(style0) and
		(style1) and
		(style0.trim().length is 0 || style0.indexOf(' ') is 0) and
		(style1.indexOf(' ') is 0)

	findIndicatorNumbersForLine: (line, length, opts) ->
		if not opts
			opts = ignoreTabs: false

		NO_INDICATOR = -1
		opts.defaultValue = NO_INDICATOR

		lineCount = @scimoz.lineCount
		allIndicators = []

		line += 2 #skip the style lines
		#Grab pairs of lines as long as they're indicator lines
		while line + 2 < lineCount
			ind0 = @lineText line += 1, false
			ind1 = @lineText line += 1, false

			indicators = null
			if @areIndicatorLines ind0, ind1
				indicators = @zipColumnNumbers ind0, ind1, opts
			else
				break

			if indicators.length < length
				#missing some values, just fill them in with whatever
				difference = length - indicators.length
				indicators.push(NO_INDICATOR) for i in [0 ... difference]
			allIndicators.push indicators
		allIndicators

	areIndicatorLines: (ind0, ind1) ->
		(ind0) and
		(ind1) and
		(ind0.indexOf('*') is 0) and
		(ind1.indexOf('*') is 0)

	zipColumnNumbers: (row0, row1, opts) ->
		#zip the rows, starting after the marker column
		lastNumber = 0
		numbers = []
		currentNumber = 0
		numberText = ''
		defaultValue = opts?.defaultValue or 0
		ignoreTabs = opts?.ignoreTabs or false

		#Calling trim() is too aggressive.
		#We just need to scrap EOL characters.
		row1 = row1.replace('\n', '')
		row1 = row1.replace('\r', '')
		for i in [1...row1.length]
			if row0[i]
				numberText = row0[i] + row1[i]
			else
				numberText = ' ' + row1[i]

			noLeadChar = numberText[0].trim().length is 0
			inTab = numberText[1] is '\t' and noLeadChar
			inDot = numberText[1] is '.' and noLeadChar

			continue if ignoreTabs and inTab

			if inTab or inDot
				currentNumber = lastNumber
			else
				numberText = numberText.trim()
				currentNumber = Number.parseInt numberText
				if Number.isNaN currentNumber
					currentNumber = defaultValue
				else
					lastNumber = currentNumber
			numbers.push currentNumber
		numbers

	updateRootProperties: ->
		propRx = /^=(\w+)\s+(.+)$/
		props = {}
		lineCount = @scimoz.lineCount
		#Sanity check
		lineCount = 100 if lineCount > 100

		for line in [0...lineCount]
			text = @lineText line
			match = propRx.exec text
			props[match[1]] = match[2] if match
			break if text.indexOf('^') is 0

		@updateLanguage props.language
		@updateEolMode props.eol

	updateLanguage: (newLang) ->
		#Keep the old language going even if it's removed from the doc.
		return unless newLang
		if @lang isnt newLang and @isValidLanguage(newLang)
			#spylog.warn "Changing language from #{@lang} to #{newLang}"
			try
				@view.language = newLang
				@lang = newLang
			catch
				#revert
				@view.language = @lang

	updateEolMode: (newEolDesc) ->
		return unless newEolDesc
		if EolMode.isValidDescriptiveString newEolDesc
			@scimoz.eOLMode = EolMode.descriptiveStringToMode newEolDesc


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

module.exports = SourceView
