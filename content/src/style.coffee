
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

		for i in [0 ... text.length]
			style = styles[i]
			switch text[i]
				when '\t'
					textLine.push '\t ' #note the trailing space!
					tensLine.push '\t'
					onesLine.push '\t'
				when '\n', '\r'
					textLine.push ' ' #strip trailing EOL
				else
					textLine.push text[i]

			tens = Math.floor(style / 10)
			ones = style % 10
			if tens is 0
				tensLine.push ' '
			else
				tensLine.push tens.toString()
			onesLine.push ones.toString()

		[textLine.join(''), tensLine.join(''), onesLine.join('')]

	@extractAllLineStylesFromCurrentEditorToClipboard = () ->
		view = ko.views.manager.currentView
		return false unless view
	
		lines = ["~language #{view.koDoc.language}"]
		try
			linesWritten = @extractAllLineStyles view, (text, styles) =>
				lines = lines.concat flatten(text, styles)

			require('sdk/clipboard').set lines.join('\n')
		catch e
			console.error e, e.stack

).call module.exports
