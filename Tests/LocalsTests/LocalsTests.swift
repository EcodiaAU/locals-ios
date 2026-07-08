import XCTest
@testable import Locals

final class LocalsTests: XCTestCase {

    func testDesignTokensLoad() {
        // Smoke test: the DesignTokens namespace compiles + the canonical Locals palette resolves.
        XCTAssertNotNil(DesignTokens.Brand.mustard)
        XCTAssertNotNil(DesignTokens.Brand.cream)
        XCTAssertNotNil(DesignTokens.Brand.ink)
    }

    func testMerchantModelDecodes() throws {
        // The PostgREST response shape from merchants_near must decode into Merchant without loss.
        let json = """
        {
          "id": "aaaaaaaa-0000-0000-0000-000000000001",
          "slug": "sunny-coast-cafe",
          "name": "Sunny Coast Cafe",
          "status": "active",
          "category": "cafe",
          "theme_colour": "mustard",
          "theme_font": "spectral",
          "distance_m": 142.0
        }
        """.data(using: .utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let merchant = try decoder.decode(Merchant.self, from: json)
        XCTAssertEqual(merchant.slug, "sunny-coast-cafe")
        XCTAssertEqual(merchant.name, "Sunny Coast Cafe")
    }
}
