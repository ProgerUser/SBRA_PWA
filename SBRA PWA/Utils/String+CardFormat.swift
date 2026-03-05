import Foundation

extension String {
    func formattedCardNumber() -> String {
        let digits = self.replacingOccurrences(of: "\\D", with: "", options: .regularExpression)
        var result = ""
        for (index, char) in digits.enumerated() {
            if index > 0 && index % 4 == 0 {
                result += " "
            }
            result.append(char)
        }
        return String(result.prefix(19)) // Max 16 digits + 3 spaces
    }
}
