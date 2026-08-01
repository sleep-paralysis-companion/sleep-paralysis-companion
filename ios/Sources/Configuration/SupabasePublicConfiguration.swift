import Foundation
import Supabase

nonisolated struct SupabasePublicConfiguration: Sendable {
    let url: URL
    let publishableKey: String
    let oauthRedirectURL: URL

    static func load(from bundle: Bundle) -> SupabasePublicConfiguration? {
        guard let rawURL = bundle.object(forInfoDictionaryKey: "SPCSupabaseURL") as? String,
              let url = URL(string: rawURL),
              url.scheme == "https",
              url.host(percentEncoded: false)?.lowercased() == "nfzvlvukbeapcnlmyecf.supabase.co",
              let key = bundle.object(forInfoDictionaryKey: "SPCSupabasePublishableKey") as? String,
              key.hasPrefix("sb_publishable_") || key.hasPrefix("eyJ"),
              key.count > 20,
              let rawRedirect = bundle.object(
                  forInfoDictionaryKey: "SPCSupabaseOAuthRedirectURL"
              ) as? String,
              let redirect = URL(string: rawRedirect),
              redirect.scheme?.lowercased() == "spc",
              redirect.host(percentEncoded: false)?.isEmpty == false
        else {
            return nil
        }
        return SupabasePublicConfiguration(
            url: url,
            publishableKey: key,
            oauthRedirectURL: redirect
        )
    }

    func makeClient() -> SupabaseClient {
        SupabaseClient(
            supabaseURL: url,
            supabaseKey: publishableKey,
            options: SupabaseClientOptions(
                auth: .init(redirectToURL: oauthRedirectURL)
            )
        )
    }
}
