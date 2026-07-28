import Foundation
import Supabase

actor SupabaseAccountDeletionGateway: AccountDeletionGateway {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func deleteAccount(requestID: UUID, accessToken: String) async throws {
        struct Request: Encodable {
            let requestID: UUID

            enum CodingKeys: String, CodingKey {
                case requestID = "request_id"
            }
        }

        try await client.functions.invoke(
            "delete-account",
            options: FunctionInvokeOptions(
                headers: ["Authorization": "Bearer \(accessToken)"],
                body: Request(requestID: requestID)
            )
        )
    }
}
