###
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
###
(->
	STYLE_UNKNOWN = 0
	STYLE_COMMENT = 2
	STYLE_STYLES = 2

	spylog = require('ko/logging').getLogger 'style-spy'

	class @View
		constructor: (@view, content) ->
			@view.initWithBuffer(content or '', 'Text')
			@scimoz = @view.scimoz
			@active = false

		applyMacHack: ->
			setTimeout (=> @view.scintilla.setAttribute 'flex', '2'), 1

		registerOnUpdate: ->
			@view.registerUpdateUICallback (args...) => @onUpdate(args...)

		onUpdate: ->

		registerOnModified: ->
			@view.addModifiedHandler @onModified, @, 100

		unregisterOnModified: ->
			@view.removeModifiedHandler @onModified

		onModified: ->

		close: ->
			@view.close()

		activate: ->
			@active = true

		passivate: ->
			@active = false

	class @SourceView extends @View
		constructor: ->
			super
			@changeCount = 0
			@registerOnUpdate()
			@registerOnModified()

		onUpdate: ->
			try
				if @active
					@updateLanguage()
					@styleAllVisible()
			finally
				@registerOnUpdate()

		onModified: ->
			++@changeCount

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
			@scimoz.setStyling lastPos - firstPos, STYLE_COMMENT
			1

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
					style = row0[i] + row1[i]
				else
					style = row1[i]

				if style in [' .', '\t\t']
					style = lastStyle
				else
					style = style.trim()
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

	class @PreviewView extends @View

		constructor: ->
			super
			@scimoz.undoCollection = false
			@scimoz.readOnly = true
			@changeCount = -1

		writeOp: (fn) ->
			@scimoz.readOnly = false
			fn()
			@scimoz.readOnly = true

		activate: ->
			super
			if @changeCount isnt @sourceView.changeCount
				@recreate()
			else
				@scrollToSource()

		recreate: ->
			@previewToSource = []
			@sourceToPreview = []

			sourceScimoz = @sourceView.scimoz

			@writeOp =>
				@scimoz.text = "Please wait..."
				@view.language = @sourceView.view.language

			@progressElement.setAttribute 'value', 0
			@progressElement.setAttribute 'hidden', 'false'

			{Ci, Cu} = require 'chrome'
			{Services} = Cu.import 'resource://gre/modules/Services.jsm'

			enqueue = (step) ->
				Services.tm.currentThread.dispatch step, Ci.nsIThread.DISPATCH_NORMAL

			#Work directly on the text, not through scimoz functions.
			#The performance difference is significant.
			sourceLines = switch sourceScimoz.eOLMode
				when 0 then sourceScimoz.text.split '\r\n'
				when 1 then sourceScimoz.text.split '\r'
				when 2 then sourceScimoz.text.split '\n'

			lineCount = sourceLines.length
			line = lineCount - 1
			inc = 100 / lineCount

			firstStep = =>
				if sourceLines[line] is '$'
					sourceLines[line] = ''
					@previewToSource.unshift line
					--line
				enqueue nextStep

			nextStep = =>
				return unless @active
				if line >= 0
					lineText = sourceLines[line]
					if lineText.charCodeAt(0) isnt 94 #'^'
						sourceLines.splice(line, 1)
					else
						sourceLines[line] = lineText[1...]
						#TODO replace ' \t' with '\t'
						@previewToSource.unshift line

					@progressElement.setAttribute 'value', (lineCount - line) * inc
					--line
					enqueue nextStep
				else
					#Done!
					previewText = switch @scimoz.eOLMode
						when 0 then sourceLines.join '\r\n'
						when 1 then sourceLines.join '\r'
						when 2 then sourceLines.join '\n'

					@writeOp =>
						@scimoz.text = previewText

					#Give ourselves a way to map to and from the source.
					for previewLine in [0 ... @previewToSource.length]
						@sourceToPreview[@previewToSource[previewLine]] = previewLine

					@scrollToSource()

					#We're fully sync'd, so sync up our change counter
					@changeCount = @sourceView.changeCount

					@progressElement.setAttribute 'hidden', 'true'


			enqueue firstStep

		scrollToSource: ->
			#Get the first visible source line
			firstSourceLine = @sourceView.scimoz.firstVisibleLine
			lineCount = @sourceView.scimoz.lineCount

			#Find the following source content line
			lineText = @sourceView.lineText firstSourceLine
			offset = 0
			good = true
			while firstSourceLine < lineCount and lineText.charCodeAt(0) isnt 94 #'^'
				++firstSourceLine
				lineText = @sourceView.lineText firstSourceLine
				#We're not showing progress, so just quit if we're running too long.
				if ++offset > 100
					good = false
					break

			#Map that to the appropriate preview line and go there!
			@scimoz.firstVisibleLine = @sourceToPreview[firstSourceLine] if good

	class @SwatchView extends @View
		constructor: ->
			super
			@language = null
			@scimoz.undoCollection = false
			@scimoz.readOnly = true
			@registerOnUpdate()
			@swatchLines = @createSwatchLines()

		updateText: () ->
			@scimoz.readOnly = false
			@language = @view.language = @sourceView.view.language
			@swatchLines[0] = "Styles for #{@language}"
			@view.scimoz.text = switch @view.scimoz.eOLMode
				when 0 then @swatchLines.join '\r\n'
				when 1 then @swatchLines.join '\r'
				when 2 then @swatchLines.join '\n'
			@scimoz.readOnly = true

		createSwatchLines: ->
			lines = ['HEADER 0', '']
			message = '0123456789ABCDEFabcdef...___|||&&&^^^***===\\\\\\---///\'\'""(){}[]'
			lines.push "Style  #{i} #{message}" for i in [0 ... 10]
			lines.push "Style #{i} #{message}" for i in [10 ... 70]
			lines

		activate: ->
			super
			if @language isnt @sourceView.view.language
				@updateText()

		onUpdate: ->
			try
				if @active
					@styleAllVisible()
			finally
				@registerOnUpdate()

		styleLine: (line, style) ->
			firstPos = @scimoz.positionFromLine line
			lastPos = @scimoz.positionFromLine line + 1
			@scimoz.startStyling firstPos, 0
			@scimoz.setStyling lastPos - firstPos, style

		styleAllVisible: ->
			#Restyle the visible lines
			firstLine = @scimoz.firstVisibleLine
			linesOnScreen = @scimoz.linesOnScreen
			lastLine = firstLine + linesOnScreen

			headerLineCount = 2

			if firstLine < headerLineCount
				#Style the header lines separately
				for line in [0 ... headerLineCount]
					@styleLine line, STYLE_COMMENT
				firstLine = headerLineCount

			if lastLine + 6 < @scimoz.lineCount
				#skip ahead 6 to minimize the flicker problem.
				lastLine += 6

			#spylog.warn "PreviewView: Styling #{firstLine} to #{lastLine}"

			for line in [firstLine ... lastLine]
				@styleLine line, line - headerLineCount

).call module.exports
