import AppKit
import SwiftUI
import TeumCore
import Carbon

final class NotePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSMenuItemValidation {
    private var store: NotebookStore!
    private var rail: NSPanel!
    private var editor: NotePanel!
    private var statusItem: NSStatusItem!
    private var screen: NSScreen?
    private var escapeMonitor: Any?
    private var hotKeys: [EventHotKeyRef] = []
    private var lastOpenedID: UUID?
    private var pendingRepositionID: UUID?
    private var eventHandler: EventHandlerRef?
    private var tabsVisible = true
    private var animationGeneration = 0
    private var railFrames: [RailItem: CGRect] = [:]
    private var railHover = RailHoverState()
    private var hoverTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let overridePath = ProcessInfo.processInfo.environment["TEUM_DATA_DIR"]
        let directory = overridePath.map { URL(fileURLWithPath: $0, isDirectory: true) }
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Teum", isDirectory: true)
        store = NotebookStore(fileURL: directory.appendingPathComponent("notes.json"))
        screen = NSScreen.main ?? NSScreen.screens.first
        setupWindows()
        setupMenu()
        setupHotKey()
        NotificationCenter.default.addObserver(self, selector: #selector(screensChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if NSApp.modalWindow != nil { return event }
            // App-directed events (including accessibility keyboards) can bypass Carbon hotkeys.
            if event.modifierFlags.intersection([.command, .control, .option, .shift]) == [.control, .option] {
                switch Int(event.keyCode) {
                case kVK_ANSI_LeftBracket: self?.previousNote(); return nil
                case kVK_ANSI_RightBracket: self?.nextNote(); return nil
                case kVK_Space: self?.toggleEditor(); return nil
                default: break
                }
            }
            let modifiers = event.modifierFlags.intersection([.command, .control, .option, .shift])
            if modifiers == [.command] {
                switch Int(event.keyCode) {
                case kVK_ANSI_N: self?.addNote(); return nil
                case kVK_ANSI_W: self?.deleteCurrentNote(); return nil
                case kVK_ANSI_Z: self?.undoAction(nil); return nil
                default: break
                }
            } else if modifiers == [.command, .shift], event.keyCode == kVK_ANSI_Z {
                self?.redoAction(nil)
                return nil
            }
            if event.keyCode == 53, self?.editor.isVisible == true,
               self?.activeTextEditor?.hasMarkedText() != true {
                self?.collapse()
                return nil
            }
            return event
        }
        positionRail()
        rail.orderFrontRegardless()
        // Sample physical pointer position independently of animated SwiftUI tracking areas.
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateRailHover() }
        }
        timer.tolerance = 0.005
        RunLoop.main.add(timer, forMode: .common)
        hoverTimer = timer
        if store.loadFailed { showError() }
        else if let first = store.notes.first { openNote(first.id, animate: false) }
    }

    private func setupWindows() {
        rail = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        editor = NotePanel(contentRect: .zero, styleMask: [.borderless], backing: .buffered, defer: false)
        for window in [rail!, editor!] {
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            window.hidesOnDeactivate = false
            window.isReleasedWhenClosed = false
        }
        rail.hasShadow = false
        rail.ignoresMouseEvents = true
        rail.title = "틈 — 가장자리 탭"
        editor.hasShadow = true
        editor.title = "틈 — 메모"
        let railView = NSHostingView(rootView: EdgeRailView(store: store, open: { [weak self] id in
            self?.toggleNote(id)
        }, add: { [weak self] in self?.addNote() }, framesChanged: { [weak self] frames in
            self?.railFrames = frames
            self?.finishPendingReposition()
        }))
        railView.sizingOptions = []
        rail.contentView = railView
        editor.contentView = NSHostingView(rootView: NoteEditorView(store: store, close: { [weak self] in
            self?.collapse()
        }, add: { [weak self] in self?.addNote() }, delete: { [weak self] id in self?.confirmDelete(id) }))
    }

    private func setupMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.righthalf.inset.filled", accessibilityDescription: "틈")
        statusItem.button?.toolTip = "틈 · 가장자리에 꽂아두는 메모"
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "틈 · 나만의 작은 여백", action: nil, keyEquivalent: ""))
        menu.addItem(.separator())
        addItem("메모 펼치기 / 접기", action: #selector(toggleEditor), to: menu)
        addItem("이전 메모", action: #selector(previousNote), to: menu)
        addItem("다음 메모", action: #selector(nextNote), to: menu)
        addItem("새 메모", action: #selector(addNote), key: "n", to: menu)
        addItem("현재 메모 삭제", action: #selector(deleteCurrentNote), key: "w", to: menu)
        addItem("실행 취소", action: #selector(undoAction(_:)), key: "z", to: menu)
        addItem("다시 실행", action: #selector(redoAction(_:)), to: menu)
        addItem("가장자리 탭 숨기기 / 보이기", action: #selector(toggleRail), to: menu)
        menu.addItem(.separator())
        addItem("왼쪽에 꽂기", action: #selector(moveLeft), to: menu)
        addItem("오른쪽에 꽂기", action: #selector(moveRight), to: menu)
        addItem("포인터가 있는 화면으로 이동", action: #selector(moveToPointerScreen), to: menu)
        menu.addItem(.separator())
        addItem("메모 저장 폴더 열기", action: #selector(revealStorage), to: menu)
        addItem("저장 다시 시도", action: #selector(retrySave), to: menu)
        menu.addItem(.separator())
        addItem("틈 종료", action: #selector(quit), key: "q", to: menu)
        statusItem.menu = menu

        // TextEditor uses the standard responder chain for Korean input, undo, and clipboard actions.
        let main = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = NSMenu()
        appItem.submenu?.addItem(withTitle: "틈 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        main.addItem(appItem)
        let fileItem = NSMenuItem(title: "파일", action: nil, keyEquivalent: "")
        let fileMenu = NSMenu(title: "파일")
        addItem("새 메모", action: #selector(addNote), key: "n", to: fileMenu)
        addItem("현재 메모 삭제", action: #selector(deleteCurrentNote), key: "w", to: fileMenu)
        fileItem.submenu = fileMenu
        main.addItem(fileItem)
        let editItem = NSMenuItem(title: "편집", action: nil, keyEquivalent: "")
        let editMenu = NSMenu(title: "편집")
        addItem("실행 취소", action: #selector(undoAction(_:)), key: "z", to: editMenu)
        let redo = editMenu.addItem(withTitle: "다시 실행", action: #selector(redoAction(_:)), keyEquivalent: "z")
        redo.target = self
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        for (title, action, key) in [("오려두기", "cut:", "x"), ("복사", "copy:", "c"), ("붙여넣기", "paste:", "v"), ("전체 선택", "selectAll:", "a")] {
            let item = editMenu.addItem(withTitle: title, action: #selector(forwardEditorCommand(_:)), keyEquivalent: key)
            item.representedObject = action
            item.target = self
        }
        editItem.submenu = editMenu
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    // Borderless accessory panels do not always participate in the main-window responder chain.
    // Route editing commands to the visible native editor instead of leaving them disabled.
    private var activeTextEditor: NSTextView? {
        guard editor?.isVisible == true else { return nil }
        func find(in view: NSView) -> NSTextView? {
            if let textView = view as? NSTextView { return textView }
            for child in view.subviews {
                if let found = find(in: child) { return found }
            }
            return nil
        }
        return editor.contentView.flatMap { find(in: $0) }
    }

    func validateMenuItem(_ item: NSMenuItem) -> Bool {
        if item.action == #selector(deleteCurrentNote) { return editor?.isVisible == true && store.selectedNote != nil }
        if item.action == #selector(undoAction(_:)) {
            return store.canUndoListChange || activeTextEditor?.undoManager?.canUndo == true
        }
        if item.action == #selector(redoAction(_:)) {
            return store.canRedoListChange || activeTextEditor?.undoManager?.canRedo == true
        }
        guard item.action == #selector(forwardEditorCommand(_:)) else { return true }
        guard let textView = activeTextEditor else { return false }
        switch item.representedObject as? String {
        case "cut:", "copy:": return textView.selectedRange().length > 0
        case "paste:": return NSPasteboard.general.availableType(from: [.string, .rtf]) != nil
        default: return true
        }
    }

    @objc private func forwardEditorCommand(_ item: NSMenuItem) {
        guard let textView = activeTextEditor else { return }
        editor.makeKeyAndOrderFront(nil)
        editor.makeFirstResponder(textView)
        switch item.representedObject as? String {
        case "cut:": textView.cut(nil)
        case "copy:": textView.copy(nil)
        case "paste:": textView.paste(nil)
        case "selectAll:": textView.selectAll(nil)
        default: break
        }
    }

    private func addItem(_ title: String, action: Selector, key: String = "", to menu: NSMenu) {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = self
    }

    private func setupHotKey() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let context = Unmanaged.passUnretained(self).toOpaque()
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let context, let event else { return OSStatus(eventNotHandledErr) }
            var identifier = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &identifier) == noErr,
                  identifier.signature == 0x5445554D else { return OSStatus(eventNotHandledErr) }
            let controller = Unmanaged<AppController>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated {
                guard NSApp.modalWindow == nil else { return }
                switch identifier.id {
                case 1: controller.toggleEditor()
                case 2: controller.previousNote()
                case 3: controller.nextNote()
                default: break
                }
            }
            return noErr
        }, 1, &eventType, context, &eventHandler)
        let shortcuts: [(UInt32, Int, Selector, String)] = [
            (1, kVK_Space, #selector(toggleEditor), "⌃⌥Space"),
            (2, kVK_ANSI_LeftBracket, #selector(previousNote), "⌃⌥["),
            (3, kVK_ANSI_RightBracket, #selector(nextNote), "⌃⌥]")
        ]
        for (id, keyCode, action, label) in shortcuts {
            var reference: EventHotKeyRef?
            let result = RegisterEventHotKey(UInt32(keyCode), UInt32(controlKey | optionKey), EventHotKeyID(signature: 0x5445554D, id: id), GetApplicationEventTarget(), 0, &reference)
            let item = statusItem.menu?.items.first { $0.action == action }
            if result == noErr, let reference {
                hotKeys.append(reference)
                item?.title += "    \(label)"
            } else {
                item?.title += " · 단축키 사용 불가"
            }
        }
    }

    private func updateRailHover() {
        guard let view = rail.contentView else { return }
        let local = view.convert(rail.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        let pointer: CGPoint? = rail.isVisible && view.bounds.contains(local) ? local : nil
        let rows = railFrames.reduce(into: [UUID: CGRect]()) { result, item in
            if case .note(let id) = item.key {
                let visible = item.value.intersection(view.bounds)
                if !visible.isNull { result[id] = visible }
            }
        }
        railHover.update(pointer: pointer, rows: rows, edge: store.notebook.edge)
        if store.hoveredNoteID != railHover.hoveredNoteID { store.hoveredNoteID = railHover.hoveredNoteID }

        let capturesPointer = pointer.map { point in
            railHover.hoveredNoteID != nil || RailHoverState.isOverCollapsedTab(point, rows: rows, edge: store.notebook.edge) || railFrames[.add]?.contains(point) == true
        } ?? false
        // The empty transparent region passes clicks and scrolling through to other apps.
        rail.ignoresMouseEvents = !capturesPointer
    }

    private func positionRail() {
        guard let screen else { return }
        let visible = screen.visibleFrame
        let height = min(CGFloat(store.notes.count) * 34 + 40, visible.height - 48)
        let width = RailLayout.expandedWidth
        let x = store.notebook.edge == .right ? visible.maxX - width : visible.minX
        let target = NSRect(x: x, y: visible.midY - height / 2, width: width, height: height)
        rail.setFrame(target, display: true)
    }

    private func toggleNote(_ id: UUID) {
        if store.selectedID == id, editor.isVisible { collapse() }
        else { openNote(id) }
    }

    private func noteTabCenterY(_ id: UUID) -> CGFloat? {
        guard let view = rail.contentView, let row = railFrames[.note(id)] else { return nil }
        guard view.bounds.contains(row) else { return nil }
        let localY = view.isFlipped ? row.midY : view.bounds.height - row.midY
        let basePoint = view.convert(NSPoint(x: row.midX, y: localY), to: nil)
        return rail.convertPoint(toScreen: basePoint).y
    }

    private func finishPendingReposition() {
        guard let id = pendingRepositionID,
              editor.isVisible,
              store.selectedID == id,
              let screen,
              let anchor = noteTabCenterY(id) else { return }
        pendingRepositionID = nil
        editor.setFrame(PanelPlacement.editorFrame(visibleFrame: screen.visibleFrame, edge: store.notebook.edge, railWidth: RailLayout.expandedWidth, anchorY: anchor), display: true)
    }

    private func openNote(_ id: UUID, animate: Bool = true) {
        guard let screen else { return }
        store.flush()
        lastOpenedID = id
        let wasVisible = editor.isVisible
        animationGeneration += 1
        store.selectedID = id
        if tabsVisible { rail.orderFrontRegardless() }
        let visibleTabY = noteTabCenterY(id)
        pendingRepositionID = visibleTabY == nil ? id : nil
        if pendingRepositionID != nil { store.scrollRequest = NoteScrollRequest(noteID: id) }
        let target = PanelPlacement.editorFrame(visibleFrame: screen.visibleFrame, edge: store.notebook.edge, railWidth: RailLayout.expandedWidth, anchorY: visibleTabY ?? rail.frame.midY)
        editor.alphaValue = 1
        if animate && !wasVisible && pendingRepositionID == nil && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            editor.setFrame(target.offsetBy(dx: store.notebook.edge == .right ? 26 : -26, dy: 0), display: false)
            editor.alphaValue = 0
            editor.makeKeyAndOrderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.18
                editor.animator().setFrame(target, display: true)
                editor.animator().alphaValue = 1
            }
        } else {
            editor.setFrame(target, display: true)
            editor.makeKeyAndOrderFront(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
        // A layout callback can arrive before the panel becomes visible.
        // Complete the placement now if scrolling has already exposed the tab.
        finishPendingReposition()
    }

    private func collapse() {
        store.flush()
        pendingRepositionID = nil
        animationGeneration += 1
        let generation = animationGeneration
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else {
            editor.orderOut(nil)
            store.selectedID = nil
            return
        }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            editor.animator().alphaValue = 0
        } completionHandler: { [weak self] in
            MainActor.assumeIsolated {
                guard let self, self.animationGeneration == generation else { return }
                self.editor.orderOut(nil)
                self.store.selectedID = nil
            }
        }
    }

    @objc private func addNote() {
        guard let id = store.addNote() else { showError(); return }
        positionRail()
        openNote(id)
    }

    @objc private func deleteCurrentNote() {
        guard editor.isVisible, let id = store.selectedID else { return }
        confirmDelete(id)
    }

    private func confirmDelete(_ id: UUID) {
        guard let note = store.notes.first(where: { $0.id == id }) else { return }
        if !note.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let alert = NSAlert()
            alert.messageText = "이 메모를 삭제할까요?"
            alert.informativeText = "삭제한 뒤에도 ⌘Z로 되돌릴 수 있습니다."
            alert.addButton(withTitle: "취소")
            alert.addButton(withTitle: "삭제")
            guard alert.runModal() == .alertSecondButtonReturn else { return }
        }
        pendingRepositionID = nil
        guard store.deleteNote(id) else { return }
        positionRail()
        showCurrentNoteOrEmptyState()
        if !store.flush() { showError() }
    }

    @objc private func undoAction(_ sender: Any?) {
        if store.prefersListUndo, applyListChange(store.undoListChange()) { return }
        if let textView = activeTextEditor, textView.undoManager?.canUndo == true {
            editor.makeKeyAndOrderFront(nil)
            editor.makeFirstResponder(textView)
            textView.undoManager?.undo()
            return
        }
        _ = applyListChange(store.undoListChange())
    }

    @objc private func redoAction(_ sender: Any?) {
        if store.prefersListRedo, applyListChange(store.redoListChange()) { return }
        if let textView = activeTextEditor, textView.undoManager?.canRedo == true {
            editor.makeKeyAndOrderFront(nil)
            editor.makeFirstResponder(textView)
            textView.undoManager?.redo()
            return
        }
        _ = applyListChange(store.redoListChange())
    }

    @discardableResult
    private func applyListChange(_ outcome: NoteListHistory.Outcome?) -> Bool {
        guard outcome != nil else { return false }
        positionRail()
        showCurrentNoteOrEmptyState()
        if !store.flush() { showError() }
        return true
    }

    private func showCurrentNoteOrEmptyState() {
        if let id = store.selectedID ?? store.notes.last?.id {
            openNote(id, animate: false)
        } else {
            lastOpenedID = nil
            editor.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func toggleEditor() {
        if editor.isVisible { collapse() }
        else if let id = NoteNavigation.resumeID(in: store.notes.map(\.id), lastOpened: lastOpenedID) { openNote(id) }
        else { addNote() }
    }

    @objc private func previousNote() { navigateNote(.previous) }
    @objc private func nextNote() { navigateNote(.next) }

    private func navigateNote(_ direction: NoteNavigation.Direction) {
        guard let id = NoteNavigation.adjacentID(in: store.notes.map(\.id), current: store.selectedID ?? lastOpenedID, direction: direction) else { return }
        openNote(id)
    }

    @objc private func toggleRail() {
        tabsVisible.toggle()
        if tabsVisible { rail.orderFrontRegardless() }
        else { collapse(); rail.orderOut(nil) }
    }

    @objc private func moveLeft() { changeEdge(.left) }
    @objc private func moveRight() { changeEdge(.right) }
    private func changeEdge(_ edge: ScreenEdge) {
        store.setEdge(edge)
        positionRail()
        if let id = store.selectedID { openNote(id, animate: false) }
    }

    @objc private func moveToPointerScreen() {
        screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        positionRail()
        if let id = store.selectedID { openNote(id, animate: false) }
    }

    @objc private func screensChanged() {
        let numberKey = NSDeviceDescriptionKey("NSScreenNumber")
        let number = screen?.deviceDescription[numberKey] as? NSNumber
        screen = NSScreen.screens.first { ($0.deviceDescription[numberKey] as? NSNumber) == number } ?? NSScreen.main
        positionRail()
        if let id = store.selectedID { openNote(id, animate: false) }
    }

    @objc private func revealStorage() {
        NSWorkspace.shared.open(store.fileURL.deletingLastPathComponent())
    }

    @objc private func retrySave() {
        if !store.flush() { showError() }
    }

    private func showError() {
        let alert = NSAlert()
        alert.messageText = "메모 파일을 확인해 주세요"
        alert.informativeText = store.errorMessage ?? "메모를 저장하지 못했습니다."
        alert.addButton(withTitle: "확인")
        alert.addButton(withTitle: "저장 폴더 열기")
        if alert.runModal() == .alertSecondButtonReturn { revealStorage() }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        if store.loadFailed || store.flush() { return .terminateNow }
        let alert = NSAlert()
        alert.messageText = "아직 저장되지 않은 내용이 있습니다"
        alert.informativeText = "종료하면 최근 변경을 잃을 수 있습니다. 저장 위치를 확인하고 다시 시도해 주세요."
        alert.addButton(withTitle: "돌아가기")
        alert.addButton(withTitle: "저장하지 않고 종료")
        return alert.runModal() == .alertSecondButtonReturn ? .terminateNow : .terminateCancel
    }

    func applicationWillTerminate(_ notification: Notification) {
        hoverTimer?.invalidate()
        for hotKey in hotKeys { UnregisterEventHotKey(hotKey) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
        if let escapeMonitor { NSEvent.removeMonitor(escapeMonitor) }
    }

}
