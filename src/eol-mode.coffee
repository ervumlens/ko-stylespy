
class EolMode
	@MODE_CRLF: 0
	@MODE_CR: 1
	@MODE_LF: 2
	@MODE_NL: 2
	@MODE_DEFAULT: @MODE_LF

	@stringToMode: (str) =>
		return @MODE_DEFAULT unless str
		return @MODE_CRLF if str[-2...] is '\r\n'
		switch str[-1...]
			when '\r' then @MODE_CR
			when '\n' then @MODE_LF
			else @MODE_DEFAULT

	@modeToString: (mode) =>
		switch mode
			when @MODE_CRLF then '\r\n'
			when @MODE_CR then '\r'
			else '\n'

	constructor: (@mode) ->
		@string = EolMode.modeToString @mode

module.exports = EolMode
