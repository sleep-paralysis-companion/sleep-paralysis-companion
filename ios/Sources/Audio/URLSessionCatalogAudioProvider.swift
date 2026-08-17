import Foundation

nonisolated struct URLSessionCatalogAudioRemoteProvider: CatalogAudioRemoteProviding {
    private let manifestURL: URL
    private let authorizationURL: URL
    private let session: URLSession
    private let allowedHosts: Set<String>

    init(
        manifestURL: URL,
        authorizationURL: URL,
        session: URLSession = .shared,
        allowedHosts: Set<String>
    ) throws {
        guard manifestURL.scheme?.lowercased() == "https",
              authorizationURL.scheme?.lowercased() == "https",
              manifestURL.user == nil,
              manifestURL.password == nil,
              authorizationURL.user == nil,
              authorizationURL.password == nil,
              !allowedHosts.isEmpty
        else {
            throw CatalogAudioBoundaryError.invalidRemoteURL
        }
        self.manifestURL = manifestURL
        self.authorizationURL = authorizationURL
        self.session = session
        self.allowedHosts = Set(allowedHosts.map { $0.lowercased() })
    }

    func loadManifest() async throws -> CatalogAudioManifest {
        let (data, response) = try await session.data(from: manifestURL)
        try validate(response: response, allowedHosts: allowedHosts)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let manifest = try decoder.decode(CatalogAudioManifest.self, from: data)
        try CatalogAudioManifestValidator.validate(manifest)
        return manifest
    }

    func authorizedURL(
        for asset: CatalogAudioAsset,
        purpose: CatalogAudioURLPurpose
    ) async throws -> URL {
        var components = URLComponents(
            url: authorizationURL,
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(name: "asset_id", value: asset.id),
            URLQueryItem(name: "content_version", value: String(asset.contentVersion)),
            URLQueryItem(name: "purpose", value: purpose.rawValue),
        ]
        guard let requestURL = components?.url else {
            throw CatalogAudioBoundaryError.invalidRemoteURL
        }
        let (data, response) = try await session.data(from: requestURL)
        try validate(response: response, allowedHosts: allowedHosts)
        let result = try JSONDecoder().decode(AuthorizedAudioURLResponse.self, from: data)
        guard result.url.scheme?.lowercased() == "https",
              result.url.user == nil,
              result.url.password == nil,
              let host = result.url.host?.lowercased(),
              allowedHosts.contains(host)
        else {
            throw CatalogAudioBoundaryError.invalidRemoteURL
        }
        return result.url
    }

    private func validate(response: URLResponse, allowedHosts: Set<String>) throws {
        guard let http = response as? HTTPURLResponse else {
            throw CatalogAudioBoundaryError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw CatalogAudioBoundaryError.httpStatus(http.statusCode)
        }
        guard let host = http.url?.host?.lowercased(),
              allowedHosts.contains(host)
        else {
            throw CatalogAudioBoundaryError.invalidResponse
        }
    }

    private struct AuthorizedAudioURLResponse: Decodable {
        let url: URL
    }
}

nonisolated struct URLSessionCatalogAudioTransfer: CatalogAudioTransferring {
    private let session: URLSession
    private let allowedHosts: Set<String>

    init(session: URLSession = .shared, allowedHosts: Set<String>) {
        self.session = session
        self.allowedHosts = Set(allowedHosts.map { $0.lowercased() })
    }

    func download(
        from url: URL,
        to temporaryURL: URL,
        assetID: String,
        expectedByteCount: Int64,
        progress: @escaping @Sendable (CatalogAudioDownloadProgress) async -> Void
    ) async throws -> CatalogAudioDownloadedFile {
        guard url.scheme?.lowercased() == "https",
              url.user == nil,
              url.password == nil,
              let host = url.host?.lowercased(),
              allowedHosts.contains(host)
        else {
            throw CatalogAudioBoundaryError.invalidRemoteURL
        }

        let (bytes, response) = try await session.bytes(from: url)
        guard let http = response as? HTTPURLResponse else {
            throw CatalogAudioBoundaryError.invalidResponse
        }
        guard (200 ... 299).contains(http.statusCode) else {
            throw CatalogAudioBoundaryError.httpStatus(http.statusCode)
        }
        guard let responseHost = http.url?.host?.lowercased(),
              allowedHosts.contains(responseHost)
        else {
            throw CatalogAudioBoundaryError.invalidResponse
        }

        let expectedFromResponse = http.expectedContentLength > 0
            ? http.expectedContentLength
            : expectedByteCount
        FileManager.default.createFile(atPath: temporaryURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: temporaryURL)
        var buffer = Data()
        buffer.reserveCapacity(65536)
        var received: Int64 = 0
        do {
            for try await byte in bytes {
                try Task.checkCancellation()
                buffer.append(byte)
                received += 1
                if buffer.count >= 65536 {
                    try handle.write(contentsOf: buffer)
                    buffer.removeAll(keepingCapacity: true)
                    await progress(
                        CatalogAudioDownloadProgress(
                            assetID: assetID,
                            bytesReceived: received,
                            totalBytes: expectedFromResponse
                        )
                    )
                }
            }
            if !buffer.isEmpty {
                try handle.write(contentsOf: buffer)
            }
            try handle.close()
            await progress(
                CatalogAudioDownloadProgress(
                    assetID: assetID,
                    bytesReceived: received,
                    totalBytes: expectedFromResponse
                )
            )
            return CatalogAudioDownloadedFile(
                temporaryURL: temporaryURL,
                byteCount: received
            )
        } catch is CancellationError {
            try? handle.close()
            try? FileManager.default.removeItem(at: temporaryURL)
            throw CatalogAudioBoundaryError.interrupted
        } catch {
            try? handle.close()
            try? FileManager.default.removeItem(at: temporaryURL)
            throw error
        }
    }
}
