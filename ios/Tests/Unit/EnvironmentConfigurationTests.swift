import Foundation
import XCTest
@testable import SleepParalysisCompanion

final class EnvironmentConfigurationTests: XCTestCase {
    func testEnvironmentRawValuesAreStable() {
        XCTAssertEqual(AppEnvironment.development.rawValue, "development")
        XCTAssertEqual(AppEnvironment.staging.rawValue, "staging")
        XCTAssertEqual(AppEnvironment.production.rawValue, "production")
    }

    func testDevelopmentSchemeSelectsDevelopmentEnvironment() {
        XCTAssertEqual(AppEnvironment.compiled, .development)
    }

    func testMissingOptionalEndpointFailsClosedWithoutInventingAHost() {
        let result = AppConfiguration.resolve(
            environment: .development,
            values: .empty
        )

        guard case .ready(let configuration) = result else {
            return XCTFail("Expected an endpoint-free configuration.")
        }

        XCTAssertNil(configuration.url(for: .publicAPI))
    }

    func testDevelopmentRejectsProductionHost() throws {
        let productionURL = try XCTUnwrap(URL(string: "https://api.production.example"))
        let values = PublicConfigurationValues(
            publicAPIBaseURL: productionURL,
            allowedHosts: ["api.production.example"],
            productionHosts: ["api.production.example"]
        )

        XCTAssertEqual(
            AppConfiguration.resolve(environment: .development, values: values),
            .unavailable(SafeDiagnostic(code: .productionResourceRejected))
        )
    }

    func testStagingRejectsProductionHost() throws {
        let productionURL = try XCTUnwrap(URL(string: "https://api.production.example"))
        let values = PublicConfigurationValues(
            publicAPIBaseURL: productionURL,
            allowedHosts: ["api.production.example"],
            productionHosts: ["api.production.example"]
        )

        XCTAssertEqual(
            AppConfiguration.resolve(environment: .staging, values: values),
            .unavailable(SafeDiagnostic(code: .productionResourceRejected))
        )
    }

    func testInsecureOrMalformedConfigurationReturnsSafeDiagnostic() throws {
        let insecureURL = try XCTUnwrap(URL(string: "http://api.development.example"))
        let values = PublicConfigurationValues(
            publicAPIBaseURL: insecureURL,
            allowedHosts: ["api.development.example"],
            productionHosts: []
        )

        let result = AppConfiguration.resolve(environment: .development, values: values)
        XCTAssertEqual(
            result,
            .unavailable(SafeDiagnostic(code: .configurationUnavailable))
        )

        guard case .unavailable(let diagnostic) = result else {
            return XCTFail("Expected a safe diagnostic.")
        }
        XCTAssertFalse(diagnostic.userMessage.contains("http"))
        XCTAssertFalse(diagnostic.userMessage.contains("api.development.example"))
    }

    func testDevelopmentRejectsAHostThatIsNotExplicitlyAllowed() throws {
        let unexpectedURL = try XCTUnwrap(URL(string: "https://unexpected.example"))
        let values = PublicConfigurationValues(
            publicAPIBaseURL: unexpectedURL,
            allowedHosts: ["api.development.example"],
            productionHosts: []
        )

        XCTAssertEqual(
            AppConfiguration.resolve(environment: .development, values: values),
            .unavailable(SafeDiagnostic(code: .configurationUnavailable))
        )
    }
}
