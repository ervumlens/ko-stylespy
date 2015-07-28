extend = (obj,name, fn = (->{})) -> obj[name] = fn() if typeof(obj[name]) is 'undefined'

extend ko, 'extensions'
extend ko.extensions, 'stylespy'
extend ko.extensions.stylespy, 'style', -> require 'stylespy/style'
#extend ko.extensions.stylespy.ui, -> require 'stylespy/ui/stylespy'
