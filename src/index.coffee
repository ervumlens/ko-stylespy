###
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
###
extend = (obj,name, fn = (->{})) -> obj[name] = fn() if typeof(obj[name]) is 'undefined'

extend ko, 'extensions'
extend ko.extensions, 'stylespy', -> require 'stylespy/style'
