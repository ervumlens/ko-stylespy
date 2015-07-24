xtk.include("domutils");

gDoc = null
gView = null
spylog = ko.logging.getLogger 'style-spy'
style = require 'koqatools/style'

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
			done = (result) -> gDoc.buffer = result
			source = window.arguments[0]
			progress = ko.dialogs.progress
			style.extractAllLineStyles source, progress, done

		gView.initWithBuffer gDoc.buffer, gDoc.language

		if navigator.platform.match /^Mac/
			#Bug 96209, bug 99277 - hack around scintilla display problems on the mac.
			setTimeout (-> gView.scintilla.setAttribute "flex", "2"), 1
	catch e
		spylog.error e

StyleSpyOnUnload = ->
    #gDoc.releaseView(gView);
    #The "close" method ensures the scintilla view is properly cleaned up.
    gView.close()
    gDoc.releaseReference()
    scintillaOverlayOnUnload()
