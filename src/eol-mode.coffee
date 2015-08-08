class EolMode
	@MODE_CRLF: 0
	@MODE_CR: 1
	@MODE_LF: 2
	@MODE_NL: 2
	@MODE_DEFAULT: @MODE_LF

	@endsInEol: (str) =>
		return false unless str
		return true if str[-2...] is '\r\n'
		switch str[-1...]
			when '\r', '\n' then true
			else false

	@stringToMode: (str) =>
		return @MODE_DEFAULT unless str
		return @MODE_CRLF if str[-2...] is '\r\n'
		switch str[-1...]
			when '\r' then @MODE_CR
			when '\n' then @MODE_LF
			else @MODE_DEFAULT

	@modeToStringWithoutDefault: (mode) =>
		switch mode
			when @MODE_CRLF then '\r\n'
			when @MODE_CR then '\r'
			when @MODE_LF then '\n'

	@modeToString: (mode) =>
		return @modeToStringWithoutDefault(mode) or
			@modeToStringWithoutDefault(@MODE_DEFAULT)

	@modeToDescriptiveStringWithoutDefault: (mode) =>
		switch mode
			when @MODE_CRLF then 'rn'
			when @MODE_CR then 'r'
			when @MODE_LF then 'n'

	@modeToDescriptiveString: (mode) =>
		@modeToDescriptiveStringWithoutDefault(mode) or
			@modeToDescriptiveStringWithoutDefault(@MODE_DEFAULT)

	@descriptiveStringToMode: (str) =>
		switch str
			when 'rn' then @MODE_CRLF
			when 'r' then @MODE_CR
			when 'n' then @MODE_LF
			else @MODE_DEFAULT

	@stringToDescriptiveString: (str) =>
		@modeToDescriptiveString @stringToMode(str)

	@isValidDescriptiveString: (str) =>
		str in ['rn', 'r', 'n']

	constructor: (@mode) ->
		@string = EolMode.modeToString @mode

module.exports = EolMode
