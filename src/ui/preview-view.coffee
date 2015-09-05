###
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
###
spylog	= require('ko/logging').getLogger 'style-spy'
View	= require 'stylespy/ui/view'
Stylist	= require 'stylespy/ui/stylist'
LineType = require 'stylespy/line-type'

class PreviewView extends View

	constructor: (view, @sourceView) ->
		super view
		@scimoz.undoCollection = false
		@scimoz.readOnly = true
		@changeCount = -1
		@previewToSource = []
		@sourceToPreview = []
		@stylist = new Stylist @
		@registerOnUpdate()

	localLineToSourceLine: (line) ->
		@previewToSource[line]

	classifyLine: ->
		LineType.CONTENT

	findStyleNumbersForLine: (line, length) ->
		@sourceView.findStyleNumbersForLine line, length,
			ignoreTabs: true
			throwOnBadStyles: false

	findIndicatorNumbersForLine: (line, length) ->
		@sourceView.findIndicatorNumbersForLine line, length,
			ignoreTabs: true

	writeOp: (fn) ->
		@scimoz.readOnly = false
		fn()
		@scimoz.readOnly = true

	activate: ->
		super
		@lastUpdateFirstLine = -1
		if @changeCount isnt @sourceView.changeCount
			@recreate()
		else
			@scrollToSource()

	onUpdate: ->
		try
			#Scrolled?
			needsUpdate =
				(@lastUpdateFirstLine isnt @scimoz.firstVisibleLine)

			if @active and needsUpdate
				#spylog.warn "PreviewView::onUpdate"
				@styleAllVisible()
				@lastUpdateFirstLine = @scimoz.firstVisibleLine
		finally
			@registerOnUpdate()
		false

	styleAllVisible: ->
		@stylist.styleAllVisible()

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

		#Extract lines from the source view one at a time.
		#Operate on them, rejoin them, then load them in the preview.
		sourceLines = []
		lineCount = sourceScimoz.lineCount
		line = lineCount - 1
		inc = 100 / lineCount

		#Assume our $ friend is on his own line
		#and not floating on a comment, or whatever.
		lastCharCode = sourceScimoz.getCharAt(sourceScimoz.length - 1)
		trimTrailingLine = (lastCharCode isnt 36) #'$'

		step = =>
			return unless @active
			if line >= 0
				#Copy the text from Scimoz first. This lets us avoid
				#the hassle of splitting on each kind of EOL and
				#rejoining on whatever we split. This could all be done
				#manually, for performance purposes.
				startPos = sourceScimoz.positionFromLine line
				endPos = sourceScimoz.positionFromLine line + 1
				lineText = sourceScimoz.getTextRange startPos, endPos
				if lineText.charCodeAt(0) is 94 #'^'
					#The content builder uses ' \t' in content to simplify
					#styling single tabs. Replace all ' \t' with '\t' to
					#turn the user-friendly string into an accurate one.
					sourceLines[line] = lineText[1...].split(' \t').join('\t')
					@previewToSource.unshift line

				@progressElement.setAttribute 'value', (lineCount - line) * inc
				--line
				enqueue step
			else
				#Done!
				if trimTrailingLine and sourceLines.length > 0
					lastLine = sourceLines[sourceLines.length - 1]
					lastLine = lastLine.replace '\r', ''
					lastLine = lastLine.replace '\n', ''
					sourceLines[sourceLines.length - 1] = lastLine

				previewText = sourceLines.join ''

				@writeOp =>
					@scimoz.text = previewText

				#Give ourselves a way to map to and from the source.
				for previewLine in [0 ... @previewToSource.length]
					@sourceToPreview[@previewToSource[previewLine]] = previewLine

				@scrollToSource()
				@styleAllVisible()

				#We're fully sync'd, so sync up our change counter
				@changeCount = @sourceView.changeCount

				@progressElement.setAttribute 'hidden', 'true'

		enqueue step

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

module.exports = PreviewView
