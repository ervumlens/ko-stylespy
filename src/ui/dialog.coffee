###
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
###

#The view-related bits are mostly lifted from Komodo's tail.js

TAB_SOURCE = 0
TAB_PREVIEW = 1

xtk.include 'domutils'

{SourceView, PreviewView} = require 'stylespy/ui/view'

initialized = false
sourceView = null
previewView = null
spylog = ko.logging.getLogger 'style-spy'
style = require 'stylespy/style'

@StyleSpyOnBlur = ->
@StyleSpyOnFocus = ->


appendToStyleBuffer = (buffer, source) ->
	switch source.type
		when 'view'
			done = (content) -> buffer.push content
			progress = ko.dialogs.progress
			style.extractAllLineStyles source.content, progress, done
		when 'buffer'
			buffer.push source.content
		when 'uri'
			fileService = Components.classes['@activestate.com/koFileService;1'].createInstance(Components.interfaces.koIFileService)
			file = fileService.getFileFromURINoCache source.content
			file.open 'r'
			try
				buffer.push file.readfile()
			finally
				file.close()

@StyleSpyOnLoad = ->
	try
		scintillaOverlayOnLoad()

		#The output may be a composite from multiple sites.
		#Pull everything together in a local buffer before
		#passing it on to the view.
		bufferParts = []

		if window.arguments and window.arguments.length > 0
			opts = window.arguments[0]
			if opts.sources
				appendToStyleBuffer(bufferParts, source) for source in opts.sources
			else if opts.source
				appendToStyleBuffer bufferParts, opts.source

		buffer = bufferParts.join('\n');

		sourceView = new SourceView document.getElementById('sourceView'), buffer
		previewView = new SourceView document.getElementById('previewView'), buffer

		if navigator.platform.match /^Mac/
			#Bug 96209, bug 99277 - hack around scintilla display problems on the mac.
			sourceView.applyMacHack()
			previewView.applyMacHack()

		initialized = true

	catch e
		spylog.error e

@StyleSpyOnTabSelected = (tabs, event)->
	return unless initialized

	if tabs.selectedIndex is TAB_PREVIEW
		sourceView.passivate()
		previewView.activate(sourceView)
	else
		previewView.passivate()
		sourceView.activate()


@StyleSpyOnUnload = ->
	sourceView.close() if sourceView
	previewView.close() if previewView
	scintillaOverlayOnUnload()
