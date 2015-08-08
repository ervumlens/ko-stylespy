###
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
###
(->
	spylog = require('ko/logging').getLogger 'style-spy'
	EolMode = require 'stylespy/eol-mode'

	@updateEditorViewOnlyCommands = (cmdset) ->
		if ko?.views?.manager?.currentView?.getAttribute('type') is 'editor'
			for child in cmdset.childNodes
				child.removeAttribute 'disabled'
		else
			for child in cmdset.childNodes
				child.setAttribute 'disabled', 'true'

	flatten = (text, styles) ->
		#turn a list of numbers into tall text
		#e.g. if text is "ABC = 123" and styles is [4,4,4,0,10,0,2,2,2],
		#then return:
		#^ABC = 123
		#     1
		# 4..0002..

		return ['$'] unless text.length > 0

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
                    #Note the leading space! This maps to the
                    #style number that corresponds to the tab itself.
                    #There's no way to float a style number in the middle
                    #of a content tab, so this is a reasonable alternative.
					textLine.push ' \t'
					tensLine.push '\t'
					onesLine.push '\t'
				else
                    #Anything else (including EOLs) goes back in.
					textLine.push text[i]

		tensLine.push '\n'
		onesLine.push '\n'

		[textLine, tensLine, onesLine].map (v) -> v.join('')

	class Extractor
		constructor: (@view, @finalizer, opts = {}) ->
			@currentLine = 0
			@steps = @view.scimoz.lineCount
			@lines = []
			@desc = 'Starting...'
			@stage = 'Extracting...'

			@lines.push "=language #{@view.koDoc.language}\n"
			@lines.push "=source #{opts.source}\n" if 'source' of opts

		extractLine: (lineNo) ->
			scimoz = @view.scimoz
			start = scimoz.positionFromLine lineNo
			end = scimoz.positionFromLine lineNo + 1
			text = scimoz.getTextRange(start, end)
			@desc = text
			styles = scimoz.getStyleRange(start, end)
			@lines.push "#line #{lineNo + 1}\n"
			@lines = @lines.concat flatten(text, styles)

		extractNextLine: ->
			@extractLine @currentLine++

		step: ->
			@extractNextLine()
			@finalize() if @currentLine is @steps

		cancel: ->
			#nothing to do

		finalize: ->
			#The lines typically contain EOL chars already.
			#It's possible that the last line ends on something else.
			#Check that now and accommodate it.
			lastLine = @lines[@lines.length - 1]
			if lastLine isnt '$' and not EolMode.endsInEol lastLine
				@lines[@lines.length - 1] += '\n'

			@finalizer @lines.join('')


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

			enqueue = (step) ->
				Services.tm.currentThread.dispatch step, Ci.nsIThread.DISPATCH_NORMAL

			step = =>
				if i is steps || @doCancel
					@job.cancel() if @doCancel
					@controller.done()
					return
				@job.step()
				@controller.set_stage(@job.stage) if @job.stage
				@controller.set_desc(@job.desc) if @job.desc
				@controller.set_progress_value i * inc
				++i
				enqueue step

			enqueue step

		cancel: ->
			@doCancel = true

	extractAllLineStyles = (view, progress, done, opts = {}) ->
		return false unless view?.scimoz
		path = view.koDoc.file?.displayPath

		jobOpts = {}
		jobOpts.source = path if path

		job = new Extractor view, done, jobOpts

		processor = new Processor job
		msg = "Extracting style information. Please wait."
		cancel = opts.cancel || " No styles will be copied."
		return progress processor, msg, "Extracting Styles", true, cancel

	@copyStylesFromCurrentEditorToClipboard = (window) ->
		return false unless ko?.views?.manager?.currentView?.scimoz

		op = =>
			view = ko.views.manager.currentView
			progress = ko.dialogs.progress
			done = (content) ->
				require('sdk/clipboard').set content
				window.setTimeout (-> window.alert 'Style successfully copied to clipboard.'), 1

			extractAllLineStyles view, progress, done, cancel: " No styles will be copied to the clipboard."

		#Launch the progress job asyc'ly so the calling GUI can reset.
		window.setTimeout op, 1

	@copyStylesFromCurrentEditorToDialog = (window) ->
		return false unless ko?.views?.manager?.currentView?.scimoz

		op = =>
			view = ko.views.manager.currentView
			progress = ko.dialogs.progress
			done = (content) ->
				winOpts = 'centerscreen,chrome,resizable,scrollbars,dialog=no,close';
				args = source: content
				window.openDialog 'chrome://stylespy/content/styledialog.xul', '_blank', winOpts, args

			extractAllLineStyles view, progress, done

		#Launch the progress job asyc'ly so the calling GUI can reset.
		window.setTimeout op, 1

	@openNewDialog = (window) ->
		winOpts = 'centerscreen,chrome,resizable,scrollbars,dialog=no,close';
		window.openDialog 'chrome://stylespy/content/styledialog.xul', '_blank', winOpts

	@openHelpDialog = (window) ->
		winOpts = 'centerscreen,chrome,resizable,scrollbars,dialog=no,close';

		{ Cc, Ci } = require('chrome');
		fileService = Cc['@activestate.com/koFileService;1'].createInstance(Ci.koIFileService)

		file = fileService.getFileFromURINoCache 'chrome://stylespy/content/doc/help.txt'
		file.open 'r'
		args = {}
		try
			args.source = file.readfile()
		catch e
			args.source = "An error occurred while loading the help file."
			spylog.error e
		finally
			file.close()

		window.openDialog 'chrome://stylespy/content/styledialog.xul', '_blank', winOpts, args

).call module.exports
