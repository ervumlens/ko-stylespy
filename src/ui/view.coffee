###
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
###
spylog = require('ko/logging').getLogger 'style-spy'

class @View
	@STYLE_UNKNOWN: 2
	@STYLE_COMMENT: 2
	@STYLE_STYLES: 2

	constructor: (@view, content) ->
		@view.initWithBuffer(content or '', 'Text')
		@scimoz = @view.scimoz
		@active = false


	applyMacHack: ->
		setTimeout (=> @view.scintilla.setAttribute 'flex', '2'), 1

	registerOnUpdate: ->
		@view.registerUpdateUICallback (args...) => @onUpdate(args...)

	onUpdate: ->

	registerOnModified: ->
		@view.addModifiedHandler @onModified, @, 100, 0x03 #insert & delete

	unregisterOnModified: ->
		@view.removeModifiedHandler @onModified

	onModified: ->

	close: ->
		@view.close()

	activate: ->
		@active = true

	passivate: ->
		@active = false

	styleAllVisible: ->
		

module.exports = View
