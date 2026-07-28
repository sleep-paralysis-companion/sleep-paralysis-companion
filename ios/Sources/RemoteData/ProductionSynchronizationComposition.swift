import Foundation
import Supabase

nonisolated enum ProductionSynchronizationComposition {
    static func makeEngine(
        database: LocalDatabase,
        client: SupabaseClient,
        clock: any Phase1BClock = SystemPhase1BClock(),
        random: any UnitIntervalRandom = SystemUnitIntervalRandom(),
        identifier: any IdentifierGenerating = SystemIdentifierGenerator()
    ) -> SynchronizationEngine {
        SynchronizationEngine(
            database: database,
            payloadProvider: LocalDatabaseOutboundPayloadProvider(database: database),
            remote: SupabaseRemoteMutationGateway(
                client: client,
                identifier: identifier
            ),
            clock: clock,
            random: random
        )
    }
}
