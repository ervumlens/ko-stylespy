
(->
	@version = '0.0.1'

	flatten = (text, styles) ->
		#turn a list of numbers into tall text
		#e.g. if text is "ABC = 123" and styles is [4,4,4,0,10,0,2,2,2],
		#then return:
		#^ABC = 123
		#     1
		# 4..0002..

		textLine = ['^']
		tensLine = [' ']
		onesLine = [' ']

		lastStyle = -1
		for i in [0 ... text.length]
			style = styles[i]

			if style isnt lastStyle
				tens = Math.floor(style / 10)
				ones = style % 10
				if tens is 0
					tensLine.push ' '
				else
					tensLine.push tens.toString()
				onesLine.push ones.toString()
				lastStyle = style
			else
				tensLine.push ' '
				onesLine.push '.'

			switch text[i]
				when '\t'
					textLine.push ' \t' #note the leading space!
					tensLine.push '\t'
					onesLine.push '\t'
				when '\n', '\r'
					textLine.push ' ' #strip trailing EOL
				else
					textLine.push text[i]

		[textLine, tensLine, onesLine].map (v) -> v.join('')

	class Extractor
		constructor: (@view, @finalizer) ->
			@currentLine = 0
			@steps = @view.scimoz.lineCount
			@lines = ["~language #{@view.koDoc.language}"]
			@desc = 'Starting...'
			@stage = 'Extracting...'

		extractLine: (lineNo) ->
			scimoz = @view.scimoz
			start = scimoz.positionFromLine lineNo
			end = scimoz.positionFromLine lineNo + 1
			text = scimoz.text.substr(start, end - start)
			@desc = text
			styles = scimoz.getStyleRange(start, end)
			@lines = @lines.concat flatten(text, styles)

		extractNextLine: ->
			@extractLine @currentLine++

		step: ->
			@extractNextLine()
			@finalize() if @currentLine is @steps

		finalize: ->
			@finalizer @lines.join('\n')


	#lifted from Komodo test code
	class Processor
		constructor: (@job) ->
			@controller
			@doCancel = false
		set_controller: (controller) ->
			@controller = controller
			@controller.set_progress_mode 'determined'
			{Ci, Cu} = require 'chrome'
			{Services} = Cu.import 'resource://gre/modules/Services.jsm'

			#start the job
			steps = @job.steps
			inc = 100 / steps
			i = 0
			next = =>
				step = =>
					if i is steps || @doCancel
						@controller.done()
						return
					@job.step()
					@controller.set_stage(@job.stage) if @job.stage
					@controller.set_desc(@job.desc) if @job.desc
					@controller.set_progress_value i * inc
					++i
					next()

				Services.tm.currentThread.dispatch step, Ci.nsIThread.DISPATCH_NORMAL

			next()

		cancel: ->
			@doCancel = true

	@extractAllLineStylesFromCurrentEditorToClipboardWithProgress = ->
		return false unless ko?.views?.manager?.currentView?.scimoz

		job = new Extractor ko.views.manager.currentView, (result) ->
			require('sdk/clipboard').set result

		processor = new Processor job
		msg = "Extracting style information. Please wait."
		result = ko.dialogs.progress(processor, msg, "Extracting Styles", true, " No data will be copied to the clipboard.");

).call module.exports
