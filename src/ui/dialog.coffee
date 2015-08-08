###
This Source Code Form is subject to the terms of the Mozilla Public License, v. 2.0.
If a copy of the MPL was not distributed with this file, You can obtain one at
http://mozilla.org/MPL/2.0/.
###

#The view-related bits are mostly lifted from Komodo's tail.js

SourceView = require 'stylespy/ui/source-view'
PreviewView = require 'stylespy/ui/preview-view'
SwatchView = require 'stylespy/ui/swatch-view'

[TAB_SOURCE, TAB_PREVIEW, TAB_SWATCH] = [0, 1, 2]
views = [null, null, null]
activeView = null
initialized = false
spylog = ko.logging.getLogger 'style-spy'
style = require 'stylespy/commands'
xtk.include 'domutils'

@StyleSpyOnBlur = ->
@StyleSpyOnFocus = ->
	activeView.styleAllVisible() if activeView

@StyleSpyOnResize = ->
	activeView.styleAllVisible() if activeView

@StyleSpyOnLoad = ->
	try
		scintillaOverlayOnLoad()

		buffer = ''

		if window.arguments and window.arguments.length > 0
			opts = window.arguments[0]
			if opts.source
				buffer = opts.source


		sourceView = views[0] = new SourceView document.getElementById('sourceView'), buffer
		previewView = views[1] = new PreviewView document.getElementById('previewView')
		previewView.progressElement = document.getElementById('previewProgress')
		previewView.sourceView = sourceView
		swatchView = views[2] = new SwatchView document.getElementById('swatchView')
		swatchView.sourceView = sourceView

		if navigator.platform.match /^Mac/
			#Bug 96209, bug 99277 - hack around scintilla display problems on the mac.
			view.applyMacHack() for view in views

		initialized = true

		switchView 0

	catch e
		spylog.error e

switchView = (viewIndex) ->
	activeView.passivate() if activeView
	activeView = views[viewIndex]
	activeView.activate() if activeView

@StyleSpyOnTabSelected = (tabs, event) ->
	return unless initialized
	switchView tabs.selectedIndex

@StyleSpyOnUnload = ->
	view.close() for view in views when view
	scintillaOverlayOnUnload()
