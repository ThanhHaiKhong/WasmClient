import Foundation

extension WasmClient {
    /// Result of scanning a photo.
    public struct ScanResult: Sendable, Equatable {
        public var title: String
        public var description: String
        public var categoryType: String
        public var imageURL: String
        public var characteristics: [String: String]
        public var suggestedQuestions: [String]
        public var nutrition: NutritionInfo?
        public var physical: PhysicalFeatures?
        public var price: PriceInfo?
        public var aiCommentary: AICommentary?
        public var discoverMore: [ShoppingProduct]
        public var buyNow: [Link]
        public var sources: [Link]
        public var raw: String?

        public init(
            title: String = "",
            description: String = "",
            categoryType: String = "",
            imageURL: String = "",
            characteristics: [String: String] = [:],
            suggestedQuestions: [String] = [],
            nutrition: NutritionInfo? = nil,
            physical: PhysicalFeatures? = nil,
            price: PriceInfo? = nil,
            aiCommentary: AICommentary? = nil,
            discoverMore: [ShoppingProduct] = [],
            buyNow: [Link] = [],
            sources: [Link] = [],
            raw: String? = nil
        ) {
            self.title = title
            self.description = description
            self.categoryType = categoryType
            self.imageURL = imageURL
            self.characteristics = characteristics
            self.suggestedQuestions = suggestedQuestions
            self.nutrition = nutrition
            self.physical = physical
            self.price = price
            self.aiCommentary = aiCommentary
            self.discoverMore = discoverMore
            self.buyNow = buyNow
            self.sources = sources
            self.raw = raw
        }
    }

    public struct NutritionInfo: Sendable, Equatable {
        public var kcal: String?
        public var calories: String?
        public var protein: String?
        public var carbs: String?
        public var fat: String?
        public var shelfLife: String?
        public var freshness: String?

        public init(kcal: String? = nil, calories: String? = nil, protein: String? = nil,
                    carbs: String? = nil, fat: String? = nil, shelfLife: String? = nil,
                    freshness: String? = nil) {
            self.kcal = kcal; self.calories = calories; self.protein = protein
            self.carbs = carbs; self.fat = fat; self.shelfLife = shelfLife
            self.freshness = freshness
        }
    }

    public struct PhysicalFeatures: Sendable, Equatable {
        public var fields: [String: String]
        public init(fields: [String: String] = [:]) { self.fields = fields }
    }

    public struct PriceInfo: Sendable, Equatable {
        public var averageFairMarketPrice: String?
        public var webPurchaseURL: String?
        public init(averageFairMarketPrice: String? = nil, webPurchaseURL: String? = nil) {
            self.averageFairMarketPrice = averageFairMarketPrice
            self.webPurchaseURL = webPurchaseURL
        }
    }

    public struct AICommentary: Sendable, Equatable {
        public var aiAssistantSays: String?
        public var aiSuggests: String?
        public var expertInsights: String?
        public var recommendation: String?
        public var interestingFacts: String?
        public var realOrFake: String?
        public var marketDemand: String?

        public init(aiAssistantSays: String? = nil, aiSuggests: String? = nil,
                    expertInsights: String? = nil, recommendation: String? = nil,
                    interestingFacts: String? = nil, realOrFake: String? = nil,
                    marketDemand: String? = nil) {
            self.aiAssistantSays = aiAssistantSays; self.aiSuggests = aiSuggests
            self.expertInsights = expertInsights; self.recommendation = recommendation
            self.interestingFacts = interestingFacts; self.realOrFake = realOrFake
            self.marketDemand = marketDemand
        }
    }

    public struct Link: Sendable, Equatable {
        public var title: String
        public var url: String
        public var description: String?
        public var image: String?
        public init(title: String = "", url: String = "", description: String? = nil, image: String? = nil) {
            self.title = title; self.url = url; self.description = description; self.image = image
        }
    }

    public struct ShoppingProduct: Sendable, Equatable {
        public var title: String
        public var price: String?
        public var currency: String?
        public var url: String
        public var image: String?
        public var source: String?
        public var rating: Double?
        public var reviewsCount: Int?

        public init(title: String = "", price: String? = nil, currency: String? = nil,
                    url: String = "", image: String? = nil, source: String? = nil,
                    rating: Double? = nil, reviewsCount: Int? = nil) {
            self.title = title; self.price = price; self.currency = currency
            self.url = url; self.image = image; self.source = source
            self.rating = rating; self.reviewsCount = reviewsCount
        }
    }
}
