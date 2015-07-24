xtk.include("domutils");

gDoc = null
gView = null
spylog = ko.logging.getLogger 'style-spy'
style = require 'stylespy/style'

StyleSpyOnBlur = ->
StyleSpyOnFocus = ->

StyleSpyOnLoad = ->
	try
		scintillaOverlayOnLoad()
		gView = document.getElementById "view"
		documentService = Components.classes["@activestate.com/koDocumentService;1"].getService()
		gDoc = documentService.createUntitledDocument "Text"
		gDoc.addReference()
		gView = document.getElementById("view");

		if window.arguments && window.arguments[0]
			opts = window.arguments[0]
			if 'view' of opts
				done = (content) -> gDoc.buffer = content
				progress = ko.dialogs.progress
				style.extractAllLineStyles opts.view, progress, done
			else if 'buffer' of opts
				gDoc.buffer = opts.buffer

		gView.initWithBuffer gDoc.buffer, gDoc.language

		if navigator.platform.match /^Mac/
			#Bug 96209, bug 99277 - hack around scintilla display problems on the mac.
			setTimeout (-> gView.scintilla.setAttribute "flex", "2"), 1
	catch e
		spylog.error e

StyleSpyOnUnload = ->
    #The "close" method ensures the scintilla view is properly cleaned up.
    gView.close()
    gDoc.releaseReference()
    scintillaOverlayOnUnload()
