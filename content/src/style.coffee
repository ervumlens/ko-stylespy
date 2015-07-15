
(->
	@version = '0.0.1'

	readNextLine = (view, start) ->
		content = view.scimoz.text
		for pos in [start .. content.length]
			c = content[pos]
			if c in ['\n', '\r']
				++pos #count EOL as part of the line
				break
		pos

	@extractLineStyle = (view, start, receiver) ->
		end = readNextLine view, start
		scimoz = view.scimoz
		text = scimoz.text.substr(start, end - start)
		styles = scimoz.getStyleRange(start, end)
		receiver text, styles
		end

	@extractAllLineStyles = (view, receiver)->
		return 0 unless view?.scimoz?.length > 0
		length = view.scimoz.length
		lines = 0
		pos = 0
		while pos < length
			from = pos
			pos = @extractLineStyle view, pos, receiver
			++lines
			#console.log "Extracted line #{lines} from #{from} to #{pos}"
		lines

	flatten = (text, styles) ->
		#turn a list of numbers into tall text
		#e.g. if text is "ABC = 123" and styles is [4,4,4,0,10,0,2,2,2],
		#then return:
		#^ABC = 123
		#     1
		# 444000222

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

		[textLine.join(''), tensLine.join(''), onesLine.join('')]

	@extractAllLineStylesFromCurrentEditorToClipboard = (progress) ->
		progress = (->) unless progress

		view = ko.views.manager.currentView
		return false unless view

		lineCount = view.scimoz.lineCount
		currentLine = 0
		step = 101 / lineCount
		lines = ["~language #{view.koDoc.language}"]
		linesWritten = @extractAllLineStyles view, (text, styles) =>
			lines = lines.concat flatten(text, styles)
			response = progress step * ++currentLine, text
			if response is 'cancel'
				throw new Exception("Cancelled style extraction")

		require('sdk/clipboard').set lines.join('\n')

	#lifted from Komodo test code
	class Processor
		constructor: (@fn) ->
			@controller
			@doCancel = false
		set_controller: (controller) ->
			@controller = controller
			@controller.set_progress_mode 'determined'
			{Ci, Cu} = require 'chrome'
			{Services} = Cu.import 'resource://gre/modules/Services.jsm'

			uiThread = Services.tm.currentThread
			#start the process
			launch = =>
				@fn (percent, hint) =>
					return 'cancel' if @doCancel
					#@controller.set_stage(hint) if hint
					#@controller.done() if percent >= 100
					#@controller.set_progress_value percent

					@controller.set_stage 'Extracting...'
					updateController = =>
						@controller.set_desc(hint) if hint
						@controller.done() if percent >= 100
						@controller.set_progress_value percent

					uiThread.dispatch updateController, Ci.nsIThread.DISPATCH_NORMAL

			Services.tm.mainThread.dispatch launch, Ci.nsIThread.DISPATCH_NORMAL

			#catch e
			#	console.error e
			#	@doCancel = true
			#	@controller.done()

		cancel: ->
			@doCancel = true

	@extractAllLineStylesFromCurrentEditorToClipboardWithProgress = ->
		return false unless ko?.views?.manager?.currentView?.scimoz

		processor = new Processor (progress) => @extractAllLineStylesFromCurrentEditorToClipboard(progress)
		msg = "Extracting style information. Please wait."
		result = ko.dialogs.progress(processor, msg, "Extracting Styles", true, " No data will be copied to the clipboard.");

).call module.exports
