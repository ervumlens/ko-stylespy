###
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
###
spylog = require('ko/logging').getLogger 'style-spy'
View = require 'stylespy/ui/view'
EolMode = require 'stylespy/eol-mode'

class PreviewView extends View

	constructor: ->
		super
		@scimoz.undoCollection = false
		@scimoz.readOnly = true
		@changeCount = -1
		@previewToSource = []
		@sourceToPreview = []
		@registerOnUpdate()

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
		firstPreviewLine = @scimoz.firstVisibleLine
		lastPreviewLine = firstPreviewLine + @scimoz.linesOnScreen

		if firstPreviewLine > 3
			#Style a few off-screen lines to reduce
			#flicker during scrolling.
			firstPreviewLine -= 3

		lineCount = @scimoz.lineCount
		if lastPreviewLine > lineCount
			lastPreviewLine = lineCount
		else
			#Style a few lines at the end, just for kicks!
			#But seriously: this ensures scimoz doesn't overwrite
			#our preview style at random.
			if lastPreviewLine + 3 < lineCount
				lastPreviewLine += 3
			if lastPreviewLine + 3 < lineCount
				lastPreviewLine += 3


		for previewLine in [firstPreviewLine .. lastPreviewLine]
			sourceLine = @previewToSource[previewLine]
			#spylog.warn "PreviewView::styleAllVisible : preview line #{previewLine} -> source line #{sourceLine}"
			continue unless sourceLine

			firstPos = @scimoz.positionFromLine previewLine
			lastPos = @scimoz.positionFromLine previewLine + 1

			styleNumbers = @sourceView.findStyleNumbersForLine sourceLine, ignoreTabs: true, length: lastPos - firstPos
			#spylog.warn "PreviewView::styleAllVisible : style numbers: #{styleNumbers.join(',')}"

			@scimoz.startStyling firstPos, 0
			for i in [0 ... styleNumbers.length]
				@scimoz.setStyling 1, styleNumbers[i]

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

		#Source always uses NL lines, even if
		#the content represents something else.
		sourceLines = sourceScimoz.text.split '\n'

		lineCount = sourceLines.length
		line = lineCount - 1
		inc = 100 / lineCount
		addTrailingLine = (sourceLines[line] is '$')

		step = =>
			return unless @active
			if line >= 0
				lineText = sourceLines[line]
				if lineText.charCodeAt(0) isnt 94 #'^'
					sourceLines.splice(line, 1)
				else
					#The content builder uses ' \t' in content to simplify
					#styling single tabs. Replace all ' \t' with '\t' to
					#turn the user-friendly string into an accurate one.
					#TODO append the appropriate EOL here.
					sourceLines[line] = lineText[1...].split(' \t').join('\t') + '\n'
					@previewToSource.unshift line

				@progressElement.setAttribute 'value', (lineCount - line) * inc
				--line
				enqueue step
			else
				#Done!
				sourceLines.push '' if addTrailingLine
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
