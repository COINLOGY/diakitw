import Foundation

@main struct FlagChecks {
    static func main() {
        precondition(NetworkPolicy.flag(for: "US") == "🇺🇸")
        precondition(NetworkPolicy.flag(for: "DE") == "🇩🇪")
        precondition(NetworkPolicy.flag(for: "Н/Д").isEmpty)
        precondition(NetworkPolicy.flag(for: "ZZ").isEmpty)
        precondition(NetworkPolicy.flag(for: "us").isEmpty)
        print("PASS: iOS IP country flags use validated ISO alpha-2, unknown stays blank")
    }
}
