import Foundation

extension APIRequest {
    /// Create a Stripe checkout session for upgrading to a paid tier.
    /// - Parameters:
    ///   - tier: Subscription tier slug ("core", "pro", or "elite").
    ///   - billingPeriod: Billing cadence ("monthly" or "annual").
    /// - Returns: An `APIRequest` that POSTs to `/api/stripe/checkout`.
    static func stripeCheckout(tier: String, billingPeriod: String = "monthly") throws -> APIRequest {
        struct Body: Encodable {
            let tier: String
            let billingPeriod: String
        }
        return try .json(
            path: "/api/stripe/checkout",
            method: .post,
            body: Body(tier: tier, billingPeriod: billingPeriod)
        )
    }

    /// Create a Stripe billing portal session for managing an existing subscription.
    /// - Returns: An `APIRequest` that POSTs to `/api/stripe/portal`.
    static func stripePortal() -> APIRequest {
        APIRequest(
            path: "/api/stripe/portal",
            method: .post,
            headers: ["Content-Type": "application/json"]
        )
    }
}

/// Response returned by both Stripe checkout and portal endpoints.
struct StripeSessionResponse: Decodable {
    let url: String?
    let error: String?
}
