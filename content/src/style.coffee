
(->
	@version = '0.0.1'
	@COMMENT = 0
	@STYLE = 1
	@TEXT = 2

	@extractStyles = (view, start, end, receiver) ->

		styles = view.scimoz.getStyleRange start, end

		#The initial "last style" is the first style
		lastStyle = styles[0]
		count = 0
		calls = 0
		length = end - start
		for i in [0 .. length]
			style = styles[i]
			if style isnt lastStyle
				receiver @STYLE, lastStyle, count
				lastStyle = style
				count = 1
				++calls
			else
				++count
		calls

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
		text = view.scimoz.text.substr start, (end - start)
		receiver @TEXT, text

		@extractStyles view, start, end, receiver
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

	@extractAllLineStylesFromCurrentEditorToClipboard = () ->
		view = ko.views.manager.currentView
		try
			lines = []
			linesWritten = @extractAllLineStyles view, (type, a, b) =>
				switch type
					when @TEXT then lines.push a
					when @STYLE then lines.push "#{a}, #{b}"

			require('sdk/clipboard').set lines.join('\n')
		catch e
			console.error e, e.stack

).call module.exports
