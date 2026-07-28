import Foundation
import Supabase

nonisolated private struct AccountDeletionFunctionRequest: Encodable {
    let requestID: UUID

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
    }
}

actor SupabaseAccountDeletionGateway: AccountDeletionGateway {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func deleteAccount(requestID: UUID, accessToken: String) async throws {
        try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(
                headers: ["Authorization": "Bearer \(accessToken)"],
                body: AccountDeletionFunctionRequest(requestID: requestID)
            )
        )
    }
}
