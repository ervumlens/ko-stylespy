###
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
###
spylog = require('ko/logging').getLogger 'style-spy'
View = require 'stylespy/ui/view'

FIRST_STYLE_LINE = 2
MAX_STYLES = 70

FIRST_INDICATOR_LINE = FIRST_STYLE_LINE + MAX_STYLES + 1
MAX_INDICATORS = 64

class SwatchView extends View
	constructor: (view, @sourceView) ->
		super view
		@language = null
		@scimoz.undoCollection = false
		@scimoz.readOnly = true
		@swatchLines = @createSwatchLines()

	updateText: () ->
		@scimoz.readOnly = false
		@language = @view.language = @sourceView.view.language
		@swatchLines[0] = "Styles and Indicators for #{@language}"
		@view.scimoz.text = @swatchLines.join '\n'
		@scimoz.readOnly = true

	createSwatchLines: ->
		lines = ['HEADER 0', '']
		message = '0123456789ABCDEFabcdef...___|||&&&^^^***===\\\\\\---///\'\'""(){}[]'
		lines.push "Style  #{i} #{message}" for i in [0 ... 10]
		lines.push "Style #{i} #{message}" for i in [10 ... MAX_STYLES]
		lines.push ''
		lines.push "Indicator  #{i} #{message}" for i in [0 ... 10]
		lines.push "Indicator #{i} #{message}" for i in [10 ... MAX_INDICATORS]

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

	decorateLine: (line, indicator) ->
		firstPos = @scimoz.positionFromLine line
		lastPos = @scimoz.positionFromLine line + 1
		@scimoz.indicatorCurrent = indicator
		@scimoz.indicatorFillRange firstPos, lastPos - firstPos

	styleAllLines: ->
		#Style everything, who cares? NOT ME!
		@styleLine 0, View.STYLE_COMMENT
		@styleLine 1, View.STYLE_COMMENT

		for i in [0 ... MAX_STYLES]
			line = FIRST_STYLE_LINE + i
			@styleLine line, i

		for i in [0 ... MAX_INDICATORS]
			line = FIRST_INDICATOR_LINE + i
			@decorateLine line, i

module.exports = SwatchView
