###
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
###

LineType = require 'stylespy/line-type'
spylog 	= require('ko/logging').getLogger 'style-spy'

class Stylist
	constructor: (@view, opts = {}) ->
		# What style should be used when there's junk in a style line?
		# This is also used to style content before the stylingOffset.
		@defaultStyle = opts.defaultStyle or 2

		# On which column should content styling and decorating begin?
		@stylingOffset = opts.stylingOffset or 0

		# Should each update clear all visible indicators? This
		# is expensive, so default to "false".
		@alwaysClearIndicators = opts.alwaysClearIndicators

		@scimoz = @view.scimoz

	styleAllVisible: ->
		firstLine = @scimoz.firstVisibleLine
		lastLine = firstLine + @scimoz.linesOnScreen
		lineCount = @scimoz.lineCount

		#Style a few off-screen lines to reduce
		#flicker during scrolling.
		firstLine -= 3 if firstLine >= 3

		#Style a few lines at the end, just for kicks!
		#But seriously: this ensures scimoz doesn't overwrite
		#our style at random.
		remaining = lineCount - lastLine

		if remaining >= 6
			lastLine += 6
		else if remaining >= 3
			lastLine += 3
		else if remaining < 0
			lastLine = lineCount

		#spylog.warn "Styling from lines #{firstLine} to #{lastLine} (of #{lineCount} lines)."

		for line in [firstLine ... lastLine]
			@styleLine line

	styleLine: (line) ->
		type = @view.classifyLine line

		switch type
			when LineType.CONTENT
				try
					@styleContent line
					@decorateContent line
				catch e
					spylog.warn e
					#Can't style it normally, so drop back to "unknown" styling
					@applyUniformStyle line, @defaultStyle
			else
				@applyUniformStyle line, @defaultStyle

	styleContent: (line) ->
		sourceLine = @view.localLineToSourceLine line
		#spylog.warn "Stylist::styleContent : target line #{line} -> source line #{sourceLine}"
		return unless sourceLine

		firstPos = @stylingOffset + @scimoz.positionFromLine line
		lastPos = @scimoz.positionFromLine line + 1

		if @stylingOffset > 0
			@scimoz.startStyling firstPos - @stylingOffset, 0
			@scimoz.setStyling @stylingOffset, @defaultStyle

		styleNumbers = @view.findStyleNumbersForLine sourceLine, lastPos - firstPos

		#spylog.warn "Stylist::styleContent : style numbers: #{styleNumbers.join(',')}"

		@scimoz.startStyling firstPos, 0
		for i in [0 ... styleNumbers.length]
			@scimoz.setStyling 1, styleNumbers[i]

	clearAllDecorations: (firstLine, lastLine) ->
		lastLine = firstLine if not lastLine
		firstPos = @scimoz.positionFromLine firstLine
		lastPos = @scimoz.positionFromLine lastLine + 1
		length = lastPos - firstPos
		for i in [0 ... 64]
			@scimoz.indicatorCurrent = i
			@scimoz.indicatorClearRange firstPos, length

	decorateContent: (line) ->
		sourceLine = @view.localLineToSourceLine line
		#spylog.warn "Stylist::decorateContent : target line #{line} -> source line #{sourceLine}"
		return unless sourceLine

		@clearAllDecorations(line) if @alwaysClearIndicators

		firstPos = @stylingOffset + @scimoz.positionFromLine line
		lastPos = @scimoz.positionFromLine line + 1
		length = lastPos - firstPos

		indNumbers = @view.findIndicatorNumbersForLine sourceLine, length

		#spylog.warn "Stylist::decorateContent : indicator numbers: #{indNumbers.join('|')}"

		#indNumbers is an array of arrays
		for indicators in indNumbers
			#indicators are measured by caret positions,
			#rather than character positions (okay, this is a guess).
			#So to decorate character n, set the indicator at n - 1.
			pos = firstPos - 1
			for indicator in indicators
				++pos
				continue if indicator < 0
				@scimoz.indicatorCurrent = indicator
				@scimoz.indicatorFillRange pos, 1

	applyUniformStyle: (line, style) ->
		#spylog.warn "Stylist::applyUniformStyle : line #{line}, style #{style}"

		firstPos = @scimoz.positionFromLine line
		lastPos = @scimoz.positionFromLine line + 1

		@scimoz.startStyling firstPos, 0
		@scimoz.setStyling lastPos - firstPos, style

module.exports = Stylist
