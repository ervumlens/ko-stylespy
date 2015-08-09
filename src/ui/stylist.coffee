###
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
###

LineType = require 'stylespy/line-type'
spylog 	= require('ko/logging').getLogger 'style-spy'

class Stylist
	constructor: (@view, opts = {}) ->
		@defaultStyle = opts.defaultStyle or 2
		@stylingOffset = opts.stylingOffset or 0
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

		spylog.warn "Styling from lines #{firstLine} to #{lastLine} (of #{lineCount} lines)."

		for line in [firstLine ... lastLine]
			@styleLine line

	styleLine: (line) ->
		type = @view.classifyLine line

		switch type
			when LineType.CONTENT
				try
					@styleContent line
				catch
					#Can't style it normally, so drop back to "unknown" styling
					@applyUniformStyle line, @defaultStyle
			else
				@applyUniformStyle line, @defaultStyle

	styleContent: (line) ->
		sourceLine = @view.localLineToSourceLine line
		spylog.warn "Stylist::styleContent : target line #{line} -> source line #{sourceLine}"
		return unless sourceLine



		firstPos = @stylingOffset + @scimoz.positionFromLine line
		lastPos = @scimoz.positionFromLine line + 1

		if @stylingOffset > 0
			@scimoz.startStyling firstPos - @stylingOffset, 0
			@scimoz.setStyling @stylingOffset, @defaultStyle

		styleNumbers = @view.findStyleNumbersForLine sourceLine, lastPos - firstPos

		spylog.warn "Stylist::styleContent : style numbers: #{styleNumbers.join(',')}"

		@scimoz.startStyling firstPos, 0
		for i in [0 ... styleNumbers.length]
			@scimoz.setStyling 1, styleNumbers[i]

	applyUniformStyle: (line, style) ->
		spylog.warn "Stylist::applyUniformStyle : line #{line}, style #{style}"

		firstPos = @scimoz.positionFromLine line
		lastPos = @scimoz.positionFromLine line + 1

		@scimoz.startStyling firstPos, 0
		@scimoz.setStyling lastPos - firstPos, style

module.exports = Stylist
