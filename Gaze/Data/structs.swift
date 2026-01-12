struct Range: Codable {
    var bounds: ClosedRange<Int>
    var step: Int
}
struct RangeChoice: Equatable {
    var val: Int?
    let range: Range?

    static func == (lhs: RangeChoice, rhs: RangeChoice) -> Bool {
        lhs.val == rhs.val && lhs.range?.bounds.lowerBound == rhs.range?.bounds.lowerBound
            && lhs.range?.bounds.upperBound == rhs.range?.bounds.upperBound
    }

    init(val: Int? = nil, range: Range? = nil) {
        self.val = val
        self.range = range
    }

    var isNil: Bool {
        return val == nil || range == nil
    }
}
