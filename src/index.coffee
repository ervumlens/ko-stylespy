extend = (obj,name, fn = (->{})) -> obj[name] = fn() if typeof(obj[name]) is 'undefined'

extend ko, 'extensions'
extend ko.extensions, 'stylespy', -> require 'stylespy/style'
