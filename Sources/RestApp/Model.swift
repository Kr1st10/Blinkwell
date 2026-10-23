import AppKit
import SwiftUI
import CoreGraphics
import UserNotifications
import ServiceManagement
import RestCore
import RestStorage

@MainActor final class AppModel: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    @Published var preferences: Preferences { didSet { savePreferences(); configure() } }
    @Published var engine = TimerEngine()
    @Published var paused = false
    @Published var readingUntil: Date?
    @Published var status = "Начинаем спокойно"
    @Published var permission = "Уведомления не настроены"
    @Published var message: String?
    @Published var days: [DaySummary] = []
    @Published var statisticsRevision = 0
    @Published var breakKind: BreakKind?
    @Published var breakRunning = false
    @Published var breakCompleted = false
    @Published var breakCompact = false
    @Published var breakRemaining: TimeInterval = 0
    @Published var selectedPage = Page.today
    @Published var routine: RoutineSession?
    @Published var breakExercises = Exercise.allCases
    @Published var stepRemaining: TimeInterval = 0
    @Published var launchEnabled = false
    @Published var activityContext = ActivityContext()
    @Published var microphoneAvailable = false
    @Published var microphoneDetected = false
    @Published var interruptionReason: String?
    private var lastMicrophoneCheck: TimeInterval = -.infinity
    private var previousReviewID: UUID?
    let updates = UpdateManager()
    let store = StatisticsStore()
    private var timer: Timer?
    private var tokens: [NSObjectProtocol] = []
    private var screenSleeping = false
    private var systemSleeping = false
    private var locked = false
    private var previousReminder: BreakKind?
    private var pendingActivity: [ActivitySpan] = []
    private var lastSave = Date()
    private var restSession: BreakSession?
    private var breakWindow: RestPanel?
    private var reminderPanel: RestPanel?
    private var mainWindow: NSWindow?
    private var wakeRecovery = WakeRecovery()
    private var wasReading = false
    private var idleBaseline: TimeInterval?

    static func loadPreferences() -> Preferences {
        guard let data = UserDefaults.standard.data(forKey:"preferences"),
              let value = try? JSONDecoder().decode(Preferences.self,from:data) else { return Preferences() }
        return value
    }

    override init() {
        preferences = Self.loadPreferences()
        super.init()
        configure()
        UNUserNotificationCenter.current().delegate = self
        let actions = [
            UNNotificationAction(identifier: "start", title: "Начать", options: []),
            UNNotificationAction(identifier: "snooze", title: "Через 5 минут"),
            UNNotificationAction(identifier: "skip", title: "Пропустить")
        ]
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(identifier: "rest", actions: actions, intentIdentifiers: []),
            UNNotificationCategory(identifier:"idle-review",actions:[
                UNNotificationAction(identifier:"reading",title:"Я читал"),
                UNNotificationAction(identifier:"away",title:"Я отходил")
            ],intentIdentifiers:[])
        ])
        let center = NSWorkspace.shared.notificationCenter
        observe(center, NSWorkspace.willSleepNotification) { $0.systemSleeping = true; $0.tick(); $0.flush() }
        observe(center, NSWorkspace.didWakeNotification) { $0.systemSleeping = false; $0.engine.rebase(); $0.tick() }
        observe(center, NSWorkspace.screensDidSleepNotification) { $0.screenSleeping = true; $0.tick() }
        observe(center, NSWorkspace.screensDidWakeNotification) { $0.screenSleeping = false; $0.engine.rebase(); $0.tick() }
        observe(center, NSWorkspace.sessionDidResignActiveNotification) { $0.locked = true; $0.tick() }
        observe(center, NSWorkspace.sessionDidBecomeActiveNotification) { $0.locked = false; $0.engine.rebase(); $0.tick() }
        let distributed = DistributedNotificationCenter.default()
        observe(distributed, Notification.Name("com.apple.screenIsLocked")) { $0.locked = true; $0.tick() }
        observe(distributed, Notification.Name("com.apple.screenIsUnlocked")) { $0.locked = false; $0.engine.rebase(); $0.tick() }
        observe(NotificationCenter.default, NSApplication.willTerminateNotification) { $0.flush() }
        observe(NotificationCenter.default, NSApplication.didBecomeActiveNotification) {
            $0.refreshPermission(); $0.launchEnabled = SMAppService.mainApp.status == .enabled
        }
        let newTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
        newTimer.tolerance = 0.2
        RunLoop.main.add(newTimer, forMode: .common); timer = newTimer
        launchEnabled = SMAppService.mainApp.status == .enabled
        refreshStatistics(); refreshPermission(); tick()
    }

    private func observe(_ center: NotificationCenter, _ name: Notification.Name,
                         action: @escaping @MainActor (AppModel) -> Void) {
        tokens.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { if let self { action(self) } }
        })
    }
    private func configure() {
        let policy: NSApplication.ActivationPolicy = preferences.hideDockIcon ? .accessory : .regular
        if NSApp.activationPolicy() != policy {
            let visibleWindows = NSApp.windows.filter { $0.isVisible && !$0.isMiniaturized }
            let keyWindow = NSApp.keyWindow
            if NSApp.setActivationPolicy(policy) {
                // Switching to accessory can hide windows on some macOS versions.
                // Keep an already-open settings window usable without another launch.
                for window in visibleWindows { window.orderFrontRegardless() }
                keyWindow?.makeKey()
            } else {
                message = "macOS не смогла изменить значок Dock. Настройка сохранена — перезапусти Blinkwell, чтобы применить её."
            }
        }
        lastMicrophoneCheck = -.infinity
        var config = TimerConfiguration()
        config.eyesInterval = Double(max(1, preferences.eyesMinutes) * 60)
        config.bodyInterval = Double(max(1, preferences.bodyMinutes) * 60)
        config.idleThreshold = Double(max(1, preferences.idleMinutes) * 60)
        config.smart = preferences.smart; config.eyesEnabled = preferences.eyesEnabled
        config.bodyEnabled = preferences.bodyEnabled; config.naturalRest = preferences.naturalRest
        engine.configuration = config
        switch preferences.appearance {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }
    private func savePreferences() {
        if let data = try? JSONEncoder().encode(preferences) { UserDefaults.standard.set(data, forKey: "preferences") }
    }
    var quiet: Bool {
        guard preferences.quietEnabled else { return false }
        let hour = Calendar.current.component(.hour, from: Date())
        if preferences.quietStart == preferences.quietEnd { return true }
        if preferences.quietStart < preferences.quietEnd {
            return hour >= preferences.quietStart && hour < preferences.quietEnd
        }
        return hour >= preferences.quietStart || hour < preferences.quietEnd
    }
    var reading: Bool { readingUntil.map { $0 > Date() } ?? false }
    var available: Bool { !screenSleeping && !systemSleeping && !locked }
    var nextKind: BreakKind {
        if !preferences.eyesEnabled { return .body }
        if !preferences.bodyEnabled { return .eyes }
        return engine.remaining(.body) < engine.remaining(.eyes) ? .body : .eyes
    }
    func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        if wakeRecovery.update(available:available) {
            // Do not interpret pre-sleep idle time as reading/absence after unlock.
            // In particular, the first tick must not accrue sleeping seconds.
            engine.rebase(); activityContext.clearReview(); activityContext.rebase()
            idleBaseline = now; lastMicrophoneCheck = -.infinity
            if preferences.resumeAfterWake { paused = false }
        }
        let anyInput = CGEventType(rawValue: UInt32.max)! // kCGAnyInputEventType in CGEventTypes.h
        let systemIdle = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
        if now - lastMicrophoneCheck >= 5 {
            lastMicrophoneCheck = now
            let sample = preferences.deferMicrophone ? MicrophoneActivity.sample() : nil
            microphoneAvailable = sample != nil
            microphoneDetected = sample ?? false
        }
        // After leaving reading mode, elapsed reading time is not evidence of rest.
        if wasReading && !reading && !microphoneDetected && !manualQuiet { idleBaseline = now }
        wasReading = reading || microphoneDetected || manualQuiet
        let idle = min(systemIdle, idleBaseline.map { max(0, now - $0) } ?? systemIdle)
        let engaged = reading || (preferences.deferMicrophone && microphoneDetected) || activityContext.manualUntil > now
        activityContext.update(now:now,idle:idle,threshold:Double(preferences.idleMinutes*60),
            available:available,paused:paused,reading:reading,smart:preferences.smart,
            microphone:preferences.deferMicrophone && microphoneDetected,takingBreak:breakKind != nil)
        interruptionReason = activityContext.suppression(at:now)
        let activeBefore = engine.activeTotal
        engine.tick(now: now, idle: idle, available: available, paused: paused,
                    reading: engaged, takingBreak: breakKind != nil, confirmIdleRest:false)
        let added = engine.activeTotal - activeBefore
        if added > 0 {
            let end = Date()
            pendingActivity.append(ActivitySpan(start: end.addingTimeInterval(-added), end: end))
        }
        if let restSession, breakRunning {
            breakRemaining = restSession.remaining(at:now)
            if var session = routine {
                session.update(now: now)
                routine = session
                stepRemaining = session.stepRemaining(at: now)
            }
            if breakRemaining <= 0 { finishBreak() }
        }
        if !available { status = "Экран выключен или заблокирован" }
        else if breakKind != nil { status = "Время для себя" }
        else if paused { status = "Таймеры на паузе" }
        else if let interruptionReason { status = interruptionReason }
        else if reading { status = "Чтение / видео · до \(readingUntil!.formatted(date: .omitted, time: .shortened))" }
        else if !engine.isCounting { status = "Нет ввода · чтение или отдых?" }
        else { status = preferences.smart ? "Учитываем время работы за Mac" : "Обычный таймер работает" }
        if activityContext.review == nil && previousReviewID != nil {
            previousReviewID = nil
            UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers:["idle-review"])
        }
        if let review = activityContext.review, previousReviewID != review.id {
            previousReviewID = review.id
            if !quiet && !paused && !microphoneDetected && !manualQuiet {
                let content = UNMutableNotificationContent()
                content.title = "Ты читал или отходил?"
                content.body = "Время без ввода приостановлено. Уточни его в Blinkwell."
                content.categoryIdentifier = "idle-review"
                content.userInfo = ["review":review.id.uuidString]
                UNUserNotificationCenter.current().add(UNNotificationRequest(identifier:"idle-review",content:content,trigger:nil))
            }
        }
        if Date().timeIntervalSince(lastSave) >= 30 { flush() }
        if let kind = engine.pending, !quiet, interruptionReason == nil, breakKind == nil, available, !paused {
            if kind != previousReminder { presentReminder(kind) }
        } else {
            if previousReminder != nil { dismissReminder() }
        }
    }
    func flush() {
        if !pendingActivity.isEmpty && store.record(spans: pendingActivity) { pendingActivity.removeAll() }
        lastSave = Date(); refreshStatistics()
    }
    func refreshStatistics() { days = store.days(); statisticsRevision += 1 }
    func clearStatistics() {
        if store.clear() { activityContext.clearReview(); pendingActivity.removeAll(); refreshStatistics() }
        else { message = store.error }
    }
    func toggleReading() {
        if !reading { resolveIdle(asReading:true); readingUntil = Date().addingTimeInterval(3600) }
        else { readingUntil = nil }
        tick()
    }
    var hasIdleReview: Bool { activityContext.review != nil }
    var manualQuiet: Bool { activityContext.manualUntil > ProcessInfo.processInfo.systemUptime }
    func toggleManualQuiet() {
        activityContext.manualUntil = manualQuiet ? 0 : ProcessInfo.processInfo.systemUptime + 1800
        tick()
    }
    func resolveIdle(asReading: Bool) {
        guard let review = activityContext.review else { return }
        if asReading {
            engine.restoreReading(seconds:review.missingActivity)
            let end = Date().addingTimeInterval(review.end - ProcessInfo.processInfo.systemUptime)
            if review.missingActivity > 0 { pendingActivity.append(ActivitySpan(start:end.addingTimeInterval(-review.missingActivity),end:end)) }
            // The explicit reading choice also prevents another false idle pause.
            readingUntil = Date().addingTimeInterval(3600)
        } else if preferences.naturalRest {
            if review.idleDuration >= 300 { engine.reset(.body) }
            else if review.idleDuration >= 60 { engine.reset(.eyes) }
        }
        activityContext.dismissReview(); interruptionReason = activityContext.suppression(at:ProcessInfo.processInfo.systemUptime)
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers:["idle-review"])
        flush(); tick()
    }
    func dismissIdleReview() {
        activityContext.dismissReview()
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers:["idle-review"])
        tick()
    }
    func togglePause() { paused.toggle(); tick() }
    func snooze(_ kind: BreakKind) { activityContext.clearReview(); engine.snooze(kind); dismissReminder() }
    func skip(_ kind: BreakKind) { activityContext.clearReview(); engine.reset(kind); dismissReminder() }
    private func dismissReminder() {
        reminderPanel?.orderOut(nil); reminderPanel = nil; previousReminder = nil
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["rest"])
    }
    private func presentReminder(_ kind: BreakKind) {
        dismissReminder(); previousReminder = kind
        let content = UNMutableNotificationContent()
        content.title = kind.title
        content.body = kind == .eyes ? "Отведи взгляд от экрана. Можно начать, отложить или пропустить." : "Встань, пройдись и смени положение тела."
        content.categoryIdentifier = "rest"; content.userInfo = ["kind": kind.rawValue]
        if preferences.sound { content.sound = .default }
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "rest", content: content, trigger: nil))
        guard preferences.popup else { return }
        let panel = RestPanel(contentRect: NSRect(x: 0, y: 0, width: 370, height: 190),
            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.title = kind.title
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.contentView = NSHostingView(rootView: ReminderView(model:self,kind:kind)
            .background(.regularMaterial,in:RoundedRectangle(cornerRadius:18)))
        panel.configureForCurrentSpace(); panel.placeAsCard()
        reminderPanel = panel; panel.showWithoutSwitchingSpace()
    }
    func requestNotifications() {
        Task {
            do {
                let allowed = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
                permission = allowed ? "Уведомления разрешены" : "Уведомления отключены в macOS"
            } catch { permission = "Не удалось запросить уведомления" }
        }
    }
    func refreshPermission() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            permission = settings.authorizationStatus == .authorized ? "Уведомления разрешены" :
                settings.authorizationStatus == .notDetermined ? "Разреши уведомления, когда будешь готов" : "Уведомления отключены в macOS"
        }
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let reviewID = response.notification.request.content.userInfo["review"] as? String
        let raw = response.notification.request.content.userInfo["kind"] as? String
        let action = response.actionIdentifier
        Task { @MainActor in
            if let reviewID, self.activityContext.review?.id.uuidString == reviewID {
                if action == "reading" { self.resolveIdle(asReading:true) }
                else if action == "away" { self.resolveIdle(asReading:false) }
                else { self.showMain(page:.today) }
            }
            if let raw, let kind = BreakKind(rawValue: raw), self.engine.pending == kind {
                if action == "snooze" { self.snooze(kind) }
                else if action == "skip" { self.skip(kind) }
                else { self.startBreak(kind) }
            }
            completionHandler()
        }
    }
    func setLaunch(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            launchEnabled = SMAppService.mainApp.status == .enabled
            if value && !launchEnabled { message = "Подтверди автозапуск в системных настройках → Основные → Объекты входа." }
        } catch { message = "Не удалось изменить автозапуск: \(error.localizedDescription)" }
    }
    func showMain(page: Page? = nil) {
        if let page { selectedPage = page }
        NSApp.activate(ignoringOtherApps: true)
        if let mainWindow { mainWindow.makeKeyAndOrderFront(nil); return }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1000, height: 740),
            styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "Blinkwell"; window.minSize = NSSize(width: 900, height: 680)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: MainView(model: self))
        mainWindow = window; window.center(); window.makeKeyAndOrderFront(nil)
    }
    func prepareBreak(_ kind: BreakKind) {
        guard breakKind == nil else { breakWindow?.showWithoutSwitchingSpace(focus:true); return }
        activityContext.clearReview(); dismissReminder(); breakKind = kind; breakRunning = false; breakCompleted = false
        breakExercises = preferences.exercises; routine = nil; stepRemaining = 0
        restSession = BreakSession(duration:kind == .eyes ? Double(preferences.eyesSeconds) : Double(preferences.bodyDuration * 60))
        breakRemaining = restSession!.duration; breakCompact = false
        engine.rebase()
        let window = RestPanel(contentRect: NSRect(x: 0, y: 0, width: 570, height: 510),
            styleMask: [.titled,.nonactivatingPanel], backing: .buffered, defer: false)
        window.title = kind.title
        window.contentView = NSHostingView(rootView: BreakView(model:self))
        window.configureForCurrentSpace(); window.centerOnCurrentScreen()
        breakWindow = window; window.showWithoutSwitchingSpace(focus:true)
        tick()
    }
    func startBreak(_ kind: BreakKind) {
        guard breakKind == nil else { breakWindow?.showWithoutSwitchingSpace(focus:true); return }
        prepareBreak(kind); beginBreak()
    }
    func beginBreak() {
        guard breakKind != nil, !breakRunning, !breakCompleted else { return }
        guard var session = restSession else { return }
        let now = ProcessInfo.processInfo.systemUptime
        session.start(at:now); restSession = session
        breakRemaining = session.duration
        breakRunning = true; engine.rebase()
        if breakKind == .body {
            routine = RoutineSession(exercises: breakExercises, duration: breakRemaining,
                                     automatic: preferences.automaticExercises, now: now)
            stepRemaining = routine!.stepRemaining(at: now)
        }
        if breakKind == .eyes { breakWindow?.orderOut(nil) }
    }
    var currentExercise: Exercise { routine?.current ?? breakExercises.first ?? .walk }
    func moveExercise(by offset: Int) {
        guard var session = routine, breakRunning else { return }
        let now = ProcessInfo.processInfo.systemUptime
        session.move(by: offset, now: now)
        routine = session; stepRemaining = session.stepRemaining(at: now)
    }
    func setExercise(_ exercise: Exercise, enabled: Bool) {
        var chosen = preferences.exercises
        if enabled && !chosen.contains(exercise) { chosen.append(exercise) }
        if !enabled { chosen.removeAll { $0 == exercise } }
        guard !chosen.isEmpty else { return }
        preferences.exerciseIDs = Exercise.allCases.filter { chosen.contains($0) }.map(\.rawValue)
    }
    func cancelBreak() {
        if let kind = breakKind, engine.pending == kind { engine.snooze(kind) }
        closeBreak()
    }
    private func finishBreak() {
        guard let kind = breakKind else { return }
        engine.reset(kind); engine.rebase(); store.record(kind: kind); refreshStatistics()
        breakRunning = false; breakCompleted = true
        if preferences.sound { NSSound(named: "Glass")?.play() }
        breakWindow?.showWithoutSwitchingSpace()
    }
    func toggleCompactBreak() {
        guard let window = breakWindow, breakKind == .body else { return }
        breakCompact.toggle()
        if breakCompact {
            window.contentView = NSHostingView(rootView: BreakProgressCard(model:self))
            window.setContentSize(NSSize(width:380,height:240)); window.placeAsCard()
        } else {
            window.contentView = NSHostingView(rootView: BreakView(model:self))
            window.setContentSize(NSSize(width:570,height:510)); window.centerOnCurrentScreen()
        }
        window.showWithoutSwitchingSpace(focus:true)
    }
    func closeBreak() {
        breakWindow?.orderOut(nil); breakWindow = nil; restSession = nil
        breakKind = nil; breakRunning = false; breakCompleted = false; breakCompact = false; routine = nil; engine.rebase(); tick()
    }
}

func clockText(_ seconds: TimeInterval) -> String {
    let value = max(0, Int(ceil(seconds)))
    return String(format: "%02d:%02d", value / 60, value % 60)
}
