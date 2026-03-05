import Foundation

struct AccountGroup: Codable, Identifiable {
    let accNum: String
    let grpName: String
    
    enum CodingKeys: String, CodingKey {
        case accNum = "acc_num"
        case grpName = "grp_name"
    }
    
    var id: String { accNum }
}

struct AccountGroupResponse: Codable {
    let groups: [AccountGroup]
    let count: Int
}

struct AvailableGroupsResponse: Codable {
    let groups: [String]
    let count: Int
}

struct AccountExistsResponse: Codable {
    let exists: Bool
    let accNum: String
    
    enum CodingKeys: String, CodingKey {
        case exists
        case accNum = "acc_num"
    }
}
