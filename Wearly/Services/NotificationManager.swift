//
//  NotificationManager.swift
//  Wearly
//
//  Schedules a once-per-day "Today's outfit" local notification.
//
//  The body is built from whatever outfit the iPhone app has most
//  recently published into the shared App Group — so users read
//  "57° · Light Hoodie + T-shirt + Sweatpants" on their lock screen
//  instead of a vague "open the app to see".
//
//  Because `UNCalendarNotificationTrigger` freezes its content at
//  schedule time, we re-schedule whenever the app publishes new
//  widget state (see `WeatherViewModel.publishWidgetState`) so the
//  next morning's alert always reflects the latest forecast.
//

import UserNotifications
import Foundation

enum NotificationManager {

    private static let identifier = "dailyOutfit"

    @discardableResult
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        do {
            return try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
    }

    /// Schedules the daily reminder. Pulls the latest outfit + Weatherly
    /// temp out of the shared App Group so the body says exactly what
    /// to wear, not just "check the app". Safe to call repeatedly — it
    /// cancels the previous request before scheduling a new one.
    static func scheduleDaily(hour: Int = 6, minute: Int = 40) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])

        let (title, body) = buildMessage()

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        center.add(request, withCompletionHandler: nil)
    }

    static func cancel() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    // MARK: - Message building

    /// Reads the most recent widget payload and turns it into a
    /// human-readable title + body pair. Falls back gracefully to the
    /// old "Open Wearly" copy if no payload has been written yet (e.g.
    /// first launch, or notifications turned on before the first fetch).
    private static func buildMessage() -> (title: String, body: String) {
        guard let defaults = UserDefaults(suiteName: WearlyAppGroup.identifier),
              let data = defaults.data(forKey: WearlyAppGroup.widgetStateKey),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return ("Today's outfit", "Open Wearly to see what to wear.")
        }

        let temp  = json["weatherlyTemp"] as? Int    ?? 0
        let label = (json["outfitLabel"]  as? String) ?? ""

        let title = "Today's outfit · \(temp)°"
        let body  = label.isEmpty
            ? "Open Wearly to see what to wear."
            : "Wear: \(label)"
        return (title, body)
    }
}
