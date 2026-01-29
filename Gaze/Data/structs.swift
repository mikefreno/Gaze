struct Range: Codable, Equatable {
    let bounds: ClosedRange<Int>
    let step: Int
}

struct RangeChoice: Equatable {
    var value: Int?
    let range: Range?

    init(value: Int? = nil, range: Range? = nil) {
        self.value = value
        self.range = range
    }

    var isNil: Bool {
        value == nil || range == nil
    }
}
