
if typeof(ko.extensions) is 'undefined'
	ko.extensions = {}

if typeof(ko.extensions.stylespy) is 'undefined'
	ko.extensions.stylespy = {}

if typeof(ko.extensions.stylespy.style) is 'undefined'
	ko.extensions.stylespy.style = require 'stylespy/style'
