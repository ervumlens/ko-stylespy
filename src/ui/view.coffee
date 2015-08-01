###
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
###
(->
	STYLE_UNKNOWN = 0
	STYLE_COMMENT = 2
	STYLE_STYLES = 2

	class @View
		constructor: (@view, content) ->
			@view.initWithBuffer content, 'Text'
			@scimoz = @view.scimoz
			@handler = (args...) => @onUpdate(args...)
			@active = false

		applyMacHack: ->
			setTimeout (=> @view.scintilla.setAttribute 'flex', '2'), 1

		register: ->
			@view.registerUpdateUICallback @handler

		close: ->
			@view.close()

		activate: ->
			@active = true

		passivate: ->
			@active = false

		onUpdate: ->

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
					@view.language = newLang
					@lang = newLang
				catch
					#revert
					@view.language = @lang

		lineText: (line, trimRight = true) ->
			start = @scimoz.positionFromLine line
			end = @scimoz.positionFromLine line + 1
			text = @scimoz.getTextRange(start, end)
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


	class @SourceView extends @View
		activate: ->
			super
			@register()

		onUpdate: ->
			try
				if @active
					@updateLanguage()
					@styleAllVisible()
			finally
				@register()

	class @PreviewView extends @View
		activate: (sourceView) ->
			super
			@scimoz.readOnly = false
			@scimoz.undoCollection = false
			sourceScimoz = sourceView.scimoz
			@scimoz.text = sourceScimoz.text

			@progressElement.setAttribute 'value', 0
			@progressElement.setAttribute 'hidden', 'false'

			{Ci, Cu} = require 'chrome'
			{Services} = Cu.import 'resource://gre/modules/Services.jsm'

			enqueue = (step) ->
				Services.tm.currentThread.dispatch step, Ci.nsIThread.DISPATCH_NORMAL

			previewToSource = []

			lineCount = @scimoz.lineCount
			line = lineCount - 1
			inc = 100 / lineCount

			@view.language = sourceView.view.language
			@scimoz.readOnly = true
			step = =>
				return unless @active
				if line >= 0
					@progressElement.setAttribute 'value', (lineCount - line) * inc
					startPos = @scimoz.positionFromLine line
					@scimoz.readOnly = false
					if @scimoz.getCharAt(startPos) isnt 94 #"^"
						endPos = @scimoz.positionFromLine line + 1
						@scimoz.deleteRange startPos, endPos - startPos
					else
						@scimoz.deleteRange startPos, 1
						previewToSource.unshift line
					@scimoz.readOnly = true
					--line
					enqueue step
				else
					@progressElement.setAttribute 'hidden', 'true'

			enqueue step

			#@scimoz.firstVisibleLine = sourceScimoz.firstVisibleLine
			#linesOnScreen = @scimoz.linesOnScreen
			#The first visible content line is the first true visible line.
			#Look for it f
).call module.exports
