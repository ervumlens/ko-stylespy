###
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
###

LineClass = require 'stylespy/line-classification'
spylog 	= require('ko/logging').getLogger 'style-spy'

class Stylist
	constructor: (@owner, @opts = {}) ->
		@opts.ignoreTabs ||= false
		@opts.throwOnBadStyles ||= false
		@opts.defaultStyle ||= 2

	activate: ->
		@sourceView = @owner.sourceView or @owner
		@targetView = @owner
		@targetScimoz = @targetView.scimoz

	styleAllVisible: ->
		firstLine = @targetScimoz.firstVisibleLine
		lastLine = firstLine + @targetScimoz.linesOnScreen
		lineCount = @targetScimoz.lineCount

		if firstLine > 3
			#Style a few off-screen lines to reduce
			#flicker during scrolling.
			firstLine -= 3

		if lastLine > lineCount
			lastLine = lineCount
		else
			#Style a few lines at the end, just for kicks!
			#But seriously: this ensures scimoz doesn't overwrite
			#our preview style at random.
			if lastLine + 3 < lineCount
				lastLine += 3
			if lastLine + 3 < lineCount
				lastLine += 3

		for line in [firstLine .. lastLine]
			@styleLine line

	styleLine: (line) ->
		classification = @owner.classifyLine line

		switch classification
			when LineClass.CONTENT
				@styleContent line
			else
				@styleUniform line, @opts.defaultStyle

	styleContent: (line) ->
		sourceLine = @owner.localLineToSourceLine line
		#spylog.warn "Stylist::styleContent : target line #{line} -> source line #{sourceLine}"
		return unless sourceLine
		firstPos = @targetScimoz.positionFromLine line
		lastPos = @targetScimoz.positionFromLine line + 1

		styleNumbers = @sourceView.findStyleNumbersForLine sourceLine,
			ignoreTabs: @opts.ignoreTabs,
			throwOnBadStyles: @opts.throwOnBadStyles,
			length: lastPos - firstPos

		#spylog.warn "Stylist::styleContent : style numbers: #{styleNumbers.join(',')}"

		@targetScimoz.startStyling firstPos, 0
		for i in [0 ... styleNumbers.length]
			@targetScimoz.setStyling 1, styleNumbers[i]

	styleUniform: (line, style) ->
		firstPos = @targetScimoz.positionFromLine line
		lastPos = @targetScimoz.positionFromLine line + 1

		@targetScimoz.startStyling firstPos, 0
		@targetScimoz.setStyling lastPos - firstPos, style

module.exports = Stylist
