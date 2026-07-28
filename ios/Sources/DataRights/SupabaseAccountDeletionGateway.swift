import Foundation
import Supabase

private nonisolated struct AccountDeletionFunctionRequest: Encodable {
    let requestID: UUID
    let retryToken: String?

    enum CodingKeys: String, CodingKey {
        case requestID = "request_id"
        case retryToken = "retry_token"
    }
}

private nonisolated struct AccountDeletionFunctionResponse: Decodable {
    let status: String?
    let requestID: UUID?
    let retryToken: String?

    enum CodingKeys: String, CodingKey {
        case status
        case requestID = "request_id"
        case retryToken = "retry_token"
    }
}

actor SupabaseAccountDeletionGateway: AccountDeletionGateway {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func deleteAccount(
        requestID: UUID,
        accessToken: String,
        retryToken: String?
    ) async throws {
        do {
            let response: AccountDeletionFunctionResponse = try await client.functions.invoke(
                "delete-account",
                options: FunctionInvokeOptions(
                    headers: ["Authorization": "Bearer \(accessToken)"],
                    body: AccountDeletionFunctionRequest(
                        requestID: requestID,
                        retryToken: retryToken
                    )
                )
            )
            guard response.status == "completed",
                  response.requestID == requestID
            else {
                throw AccountDeletionGatewayError.rejected
            }
        } catch let FunctionsError.httpError(code, data) {
            let payload = try? JSONDecoder().decode(
                AccountDeletionFunctionResponse.self,
                from: data
            )
            if code == 503 {
                throw AccountDeletionGatewayError.recoverable(
                    retryToken: payload?.retryToken
                )
            }
            throw AccountDeletionGatewayError.rejected
        } catch let error as AccountDeletionGatewayError {
            throw error
        } catch {
            throw AccountDeletionGatewayError.recoverable(retryToken: retryToken)
        }
    }
}
