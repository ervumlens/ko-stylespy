###
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
###
spylog = require('ko/logging').getLogger 'style-spy'
View = require 'stylespy/ui/view'

class SwatchView extends View
	constructor: ->
		super
		@language = null
		@scimoz.undoCollection = false
		@scimoz.readOnly = true
		@swatchLines = @createSwatchLines()

	updateText: () ->
		@scimoz.readOnly = false
		@language = @view.language = @sourceView.view.language
		@swatchLines[0] = "Styles for #{@language}"
		@view.scimoz.text = @swatchLines.join '\n'
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
			@styleAllLines()

	styleLine: (line, style) ->
		firstPos = @scimoz.positionFromLine line
		lastPos = @scimoz.positionFromLine line + 1
		@scimoz.startStyling firstPos, 0
		@scimoz.setStyling lastPos - firstPos, style

	styleAllLines: ->
		#Style everything, who cares? NOT ME!
		@styleLine 0, View.STYLE_COMMENT
		@styleLine 1, View.STYLE_COMMENT

		lineCount = @scimoz.lineCount
		for line in [2 ... lineCount]
			@styleLine line, line - 2

module.exports = SwatchView
