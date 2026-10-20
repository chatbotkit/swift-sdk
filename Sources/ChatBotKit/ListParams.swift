import Foundation

/// Paging options for lists that belong to another resource, such as the
/// messages of a conversation or the records of a dataset.
public struct ListParams: Codable, Sendable, Hashable {
    /// The cursor returned by the previous page.
    public var cursor: String?

    /// The sort order.
    public var order: ListOrder?

    /// The number of items to return.
    public var take: Int?

    public init(cursor: String? = nil, order: ListOrder? = nil, take: Int? = nil) {
        self.cursor = cursor
        self.order = order
        self.take = take
    }
}

/// The sort order of a list.
public struct ListOrder: RawRepresentable, Codable, Sendable, Hashable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public static let asc = ListOrder(rawValue: "asc")
    public static let desc = ListOrder(rawValue: "desc")
}
