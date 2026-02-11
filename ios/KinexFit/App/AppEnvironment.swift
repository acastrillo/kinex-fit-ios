import Foundation

struct AppEnvironment {
    let apiClient: APIClient
    let tokenStore: TokenStore
    let database: AppDatabase
    let syncEngine: SyncEngine

    // Services
    let authService: AuthService
    let workoutRepository: WorkoutRepository
    let userRepository: UserRepository
    let purchaseValidator: PurchaseValidator
    let storeManager: StoreManager

    static var live: AppEnvironment {
        let tokenStore = KeychainTokenStore()
        let apiClient = APIClient(baseURL: AppConfig.apiBaseURL, tokenStore: tokenStore)

        do {
            let database = try AppDatabase()
            let syncEngine = SyncEngine(database: database, apiClient: apiClient)

            // Initialize services
            let authService = AuthService(apiClient: apiClient, tokenStore: tokenStore, database: database)
            let workoutRepository = WorkoutRepository(database: database, syncEngine: syncEngine)
            let userRepository = UserRepository(database: database, apiClient: apiClient, tokenStore: tokenStore)
            let purchaseValidator = PurchaseValidator(apiClient: apiClient, userRepository: userRepository)
            let storeManager = StoreManager(purchaseValidator: purchaseValidator)

            return AppEnvironment(
                apiClient: apiClient,
                tokenStore: tokenStore,
                database: database,
                syncEngine: syncEngine,
                authService: authService,
                workoutRepository: workoutRepository,
                userRepository: userRepository,
                purchaseValidator: purchaseValidator,
                storeManager: storeManager
            )
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }
    }

    static var preview: AppEnvironment {
        let tokenStore = InMemoryTokenStore()
        let apiClient = APIClient(baseURL: AppConfig.apiBaseURL, tokenStore: tokenStore)

        do {
            let database = try AppDatabase.inMemory()
            let syncEngine = SyncEngine(database: database, apiClient: apiClient)

            // Initialize services
            let authService = AuthService(apiClient: apiClient, tokenStore: tokenStore, database: database)
            let workoutRepository = WorkoutRepository(database: database, syncEngine: syncEngine)
            let userRepository = UserRepository(database: database, apiClient: apiClient, tokenStore: tokenStore)
            let purchaseValidator = PurchaseValidator(apiClient: apiClient, userRepository: userRepository)
            let storeManager = StoreManager(purchaseValidator: purchaseValidator)

            return AppEnvironment(
                apiClient: apiClient,
                tokenStore: tokenStore,
                database: database,
                syncEngine: syncEngine,
                authService: authService,
                workoutRepository: workoutRepository,
                userRepository: userRepository,
                purchaseValidator: purchaseValidator,
                storeManager: storeManager
            )
        } catch {
            fatalError("Failed to initialize preview database: \(error)")
        }
    }
}
