//
//  AppDelegate.swift
//  PhotoMiner
//
//  Created by Gergely Sánta on 07/12/2016.
//  Copyright © 2016 TriKatz. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
	
	var imageCollection = ImageCollection()
	
	var mainWindowController:MainWindowController? {
		get {
			for window in NSApp.windows {
				if let controller = window.windowController as? MainWindowController {
					return controller
				}
			}
			return nil
		}
	}
	
	@objc dynamic var isListingAvailable:Bool {
		get {
			let imagesAvailable = self.imageCollection.count > 0
			if let scanning = mainWindowController?.scanner.isRunning {
				// Listing is available only when not scanning
				return scanning ? false : imagesAvailable
			}
			return imagesAvailable
		}
	}
	
	@objc dynamic var isSaveAvailable:Bool {
		get {
			return isListingAvailable && (Configuration.shared.openedFileUrl != nil)
		}
	}

	func applicationDidFinishLaunching(_ aNotification: Notification) {
		// Insert code here to initialize your application
	}
	
	func applicationWillTerminate(_ aNotification: Notification) {
		// Insert code here to tear down your application
	}
	
	func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
		return true
	}
	
	func application(_ sender: NSApplication, openFile filename: String) -> Bool {
		if filename.hasSuffix(".\(Configuration.shared.saveDataExtension)") {
			loadImageDatabase(URL(fileURLWithPath: filename), onError: {})
		}
		else if Configuration.shared.setLookupDirectories([filename]) {
			mainWindowController?.startScan()
			return true
		}
		return false
	}
	
	func application(_ sender: NSApplication, openFiles filenames: [String]) {
		let savedDataFiles = filenames.filter { $0.hasSuffix(".\(Configuration.shared.saveDataExtension)") }
		if savedDataFiles.count > 0 {
			for filename in savedDataFiles {
				if loadImageDatabase(URL(fileURLWithPath: filename), onError: {}) {
					return
				}
			}
		}
		else if Configuration.shared.setLookupDirectories(filenames) {
			mainWindowController?.startScan()
		}
	}
	
	func displayErrorSheet(withMessage message: String, andInformativeText infoText: String?, forWindow window: NSWindow) {
		let alert = NSAlert()
		alert.messageText = message
		alert.informativeText = infoText ?? ""
		alert.alertStyle = .critical
		alert.addButton(withTitle: "OK")
		alert.beginSheetModal(for: window)
	}
	
	func displayErrorSheet(withMessage message: String, forWindow window: NSWindow) {
		displayErrorSheet(withMessage: message, andInformativeText: nil, forWindow: window)
	}
	
	@discardableResult private func saveImageDatabase(onError errorHandler: () -> Void) -> Bool {
		guard let window = mainWindowController?.window else { return false }
		guard let fileUrl = Configuration.shared.openedFileUrl else { return false }
		
		if let jsonData = try? JSONEncoder().encode(self.imageCollection) {
			do {
				try jsonData.write(to: fileUrl)
				return true
			} catch {
				errorHandler();
				displayErrorSheet(withMessage: "Couldn't save scan to \(fileUrl.path)", forWindow: window)
			}
		}
		else {
			errorHandler()
			displayErrorSheet(withMessage: "Couldn't prepare data for saving", forWindow: window)
		}
		return false
	}
	
	@discardableResult func loadImageDatabase(_ fileUrl: URL, onError errorHandler: () -> Void) -> Bool {
		do {
			self.imageCollection = try JSONDecoder().decode(ImageCollection.self, from: Data(contentsOf: fileUrl))
			Configuration.shared.openedFileUrl = fileUrl
			self.mainWindowController?.refreshPhotos()
			return true
		} catch {
			errorHandler();
			if let window = mainWindowController?.window {
				self.displayErrorSheet(withMessage: "Couldn't parse scan from \(fileUrl.path)",
				                andInformativeText: "File is corrupted or it's not a scan result",
				                         forWindow: window)
			}
		}
		return false
	}
	
	@IBAction func prefsMenuItemPressed(_ sender: NSMenuItem) {
		if let titleBarController = self.mainWindowController?.titlebarController {
			titleBarController.showSettings()
		}
	}
	
	@IBAction func openMenuItemPressed(_ sender: NSMenuItem) {
		guard let window = mainWindowController?.window else { return }
		
		let openPanel = NSOpenPanel()
		openPanel.allowsMultipleSelection = false
		openPanel.canChooseDirectories = false
		openPanel.canCreateDirectories = false
		openPanel.canChooseFiles = true
		openPanel.allowedFileTypes = [ Configuration.shared.saveDataExtension ]

		openPanel.beginSheetModal(for: window) { (response:NSApplication.ModalResponse) in
			if response == .OK {
				if let fileUrl = openPanel.url {
					self.loadImageDatabase(fileUrl, onError: {
						openPanel.close()
					})
				}
			}
		}
	}
	
	@IBAction func saveMenuItemPressed(_ sender: NSMenuItem) {
		saveImageDatabase(onError: {})
	}
	
	@IBAction func saveAsMenuItemPressed(_ sender: NSMenuItem) {
		guard let window = mainWindowController?.window else { return }
		
		let savePanel = NSSavePanel()
		savePanel.canCreateDirectories = true
		savePanel.allowedFileTypes = [ Configuration.shared.saveDataExtension ]
		
		savePanel.beginSheetModal(for: window, completionHandler: { (response:NSApplication.ModalResponse) in
			if response == .OK {
				if self.saveImageDatabase(onError: { savePanel.close() }) {
					Configuration.shared.openedFileUrl = savePanel.url
				}
			}
		})
	}
	
}

