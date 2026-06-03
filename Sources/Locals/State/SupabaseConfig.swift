import Foundation
import Supabase

// One Supabase client, read at startup from the Info.plist keys baked at
// build time by project.yml. The anon key is public-by-design (RLS-gated);
// it ships in the binary for every Supabase iOS app. The service key never
// touches the client; merchant writes that need it route through edge
// functions (see billing-checkout etc).

enum LocalsConfig {
    static let supabaseURL: URL = {
        let s = Bundle.main.object(forInfoDictionaryKey: "LocalsSupabaseURL") as? String
        return URL(string: s ?? "https://dpumgcxpwfigtpotayjq.supabase.co")!
    }()

    static let supabaseAnonKey: String = {
        Bundle.main.object(forInfoDictionaryKey: "LocalsSupabaseAnonKey") as? String
        ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRwdW1nY3hwd2ZpZ3Rwb3RheWpxIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODAyOTEwODIsImV4cCI6MjA5NTg2NzA4Mn0.8FhySa1u2mb5z_3g1wFVwQFdgFqsWpZeKGy0gKItMP4"
    }()
}

extension SupabaseClient {
    static let shared: SupabaseClient = SupabaseClient(
        supabaseURL: LocalsConfig.supabaseURL,
        supabaseKey: LocalsConfig.supabaseAnonKey
    )
}
