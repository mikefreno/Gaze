extension String {
    var titleCase: String {
        // The compiler didn't like this chained - `Too long to  type-check`

        guard !self.isEmpty else {
            return ""
        }

        let words = self.split(separator: " ")
            .map { word in
                guard !word.isEmpty else { return String(word) }
                return String(word.prefix(1)).uppercased() + String(word.dropFirst())
            }
            .joined(separator: " ")

        let result = words.split(separator: "-")
            .map { word in
                guard !word.isEmpty else { return String(word) }
                return String(word.prefix(1)).uppercased() + String(word.dropFirst())
            }
            .joined(separator: "-")

        return result
    }
}

