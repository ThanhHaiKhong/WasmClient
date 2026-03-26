@preconcurrency import FlowKit
import Foundation
import SwiftProtobuf
import WasmClient

// MARK: - Scan

extension WasmActor {

    /// Upload image data, then scan it via the vision engine.
    /// Returns a mapped ScanResult with all fields.
    func scan(imageData: Data, category: String, language: String) async throws -> WasmClient.ScanResult {
        let instance = try await readyEngine()

        // Step 1: upload to blobstore
        let imageURL = try await uploadImage(imageData: imageData)
        logger("Scan: uploaded image → \(imageURL)")

        // Step 2: run scan action
        let scanAction = try await delegate.resolveAction(actionID: WasmClient.ActionID.scan.rawValue, logger: logger)
        var args: [String: Google_Protobuf_Value] = [
            "file": Google_Protobuf_Value(stringValue: imageURL),
        ]
        if category != "object" {
            args["category"] = Google_Protobuf_Value(stringValue: category)
        }
        if language != "en" {
            args["language"] = Google_Protobuf_Value(stringValue: language)
        }
        let task = try await instance.create(action: scanAction, args: args)
        let visionResult = try Self.parseScanResult(task: task)
        return Self.mapScanResult(visionResult)
    }

    /// Run visual search on an already-uploaded image URL.
    func visualSearch(imageURL: String) async throws -> [WasmClient.ShoppingProduct] {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: WasmClient.ActionID.visualSearch.rawValue, logger: logger)
        let args: [String: Google_Protobuf_Value] = [
            "file": Google_Protobuf_Value(stringValue: imageURL),
        ]
        let task = try await instance.create(action: action, args: args)
        guard task.status == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        let result = try VisionDiscoverResult(unpackingAny: task.value)
        return result.products.map(Self.mapShoppingProduct)
    }

    /// Search for shopping products by text query.
    func shopping(query: String) async throws -> [WasmClient.ShoppingProduct] {
        let instance = try await readyEngine()
        let action = try await delegate.resolveAction(actionID: WasmClient.ActionID.shopping.rawValue, logger: logger)
        let args: [String: Google_Protobuf_Value] = [
            "query": Google_Protobuf_Value(stringValue: query),
        ]
        let task = try await instance.create(action: action, args: args)
        guard task.status == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        let result = try VisionShoppingResult(unpackingAny: task.value)
        return result.products.map(Self.mapShoppingProduct)
    }
}

// MARK: - Parsing & Mapping

extension WasmActor {

    private static func parseScanResult(task: WaTTask) throws -> VisionScanResult {
        guard task.status == .completed, task.hasValue else {
            throw WasmClient.Error.taskFailed(status: "\(task.status)")
        }
        if let result = try? VisionScanResult(unpackingAny: task.value) {
            return result
        }
        // Fallback: legacy TypesBytes → JSON
        let bytes = try TypesBytes(unpackingAny: task.value)
        guard case .raw(let data) = bytes.data else {
            throw WasmClient.Error.unexpectedResponseFormat
        }
        var opts = JSONDecodingOptions()
        opts.ignoreUnknownFields = true
        return try VisionScanResult(jsonUTF8Data: data, options: opts)
    }

    private static func mapScanResult(_ v: VisionScanResult) -> WasmClient.ScanResult {
        WasmClient.ScanResult(
            title: v.hasTitle ? v.title : "",
            description: v.description_p,
            categoryType: v.hasCategoryType ? v.categoryType : "",
            imageURL: v.hasImageURL ? v.imageURL : "",
            characteristics: v.hasCharacteristics ? v.characteristics.fields : [:],
            suggestedQuestions: v.suggestedQuestions,
            nutrition: v.hasNutrition ? mapNutrition(v.nutrition) : nil,
            physical: v.hasPhysical ? mapPhysical(v.physical) : nil,
            price: v.hasPrice ? mapPrice(v.price) : nil,
            aiCommentary: v.hasAiCommentary ? mapAICommentary(v.aiCommentary) : nil,
            discoverMore: v.discoverMore.map(mapShoppingProduct),
            buyNow: v.buyNow.map(mapLink),
            sources: v.sources.map(mapLink),
            raw: v.hasRaw ? v.raw : nil
        )
    }

    private static func mapNutrition(_ n: VisionNutritionInfo) -> WasmClient.NutritionInfo {
        WasmClient.NutritionInfo(
            kcal: n.hasKcal ? n.kcal : nil,
            calories: n.hasCalories ? n.calories : nil,
            protein: n.hasProtein ? n.protein : nil,
            carbs: n.hasCarbs ? n.carbs : nil,
            fat: n.hasFat ? n.fat : nil,
            shelfLife: n.hasShelfLife ? n.shelfLife : nil,
            freshness: n.hasFreshness ? n.freshness : nil
        )
    }

    private static func mapPhysical(_ p: VisionPhysicalFeatures) -> WasmClient.PhysicalFeatures {
        var fields: [String: String] = [:]
        if p.hasWeight { fields["weight"] = p.weight }
        if p.hasDiameter { fields["diameter"] = p.diameter }
        if p.hasThickness { fields["thickness"] = p.thickness }
        if p.hasComposition { fields["composition"] = p.composition }
        if p.hasGrade { fields["grade"] = p.grade }
        if p.hasRarity { fields["rarity"] = p.rarity }
        if p.hasHardnessScale { fields["hardnessScale"] = p.hardnessScale }
        if p.hasDensity { fields["density"] = p.density }
        if p.hasColor { fields["color"] = p.color }
        if p.hasFormula { fields["formula"] = p.formula }
        if p.hasLuster { fields["luster"] = p.luster }
        return WasmClient.PhysicalFeatures(fields: fields)
    }

    private static func mapPrice(_ p: VisionPriceInfo) -> WasmClient.PriceInfo {
        WasmClient.PriceInfo(
            averageFairMarketPrice: p.hasAverageFairMarketPrice ? p.averageFairMarketPrice : nil,
            webPurchaseURL: p.hasWebPurchaseURL ? p.webPurchaseURL : nil
        )
    }

    private static func mapAICommentary(_ a: VisionAICommentary) -> WasmClient.AICommentary {
        WasmClient.AICommentary(
            aiAssistantSays: a.hasAiAssistantSays ? a.aiAssistantSays : nil,
            aiSuggests: a.hasAiSuggests ? a.aiSuggests : nil,
            expertInsights: a.hasExpertInsights ? a.expertInsights : nil,
            recommendation: a.hasRecommendation ? a.recommendation : nil,
            interestingFacts: a.hasInterestingFacts ? a.interestingFacts : nil,
            realOrFake: a.hasRealOrFake ? a.realOrFake : nil,
            marketDemand: a.hasMarketDemand ? a.marketDemand : nil
        )
    }

    private static func mapShoppingProduct(_ p: VisionShoppingProduct) -> WasmClient.ShoppingProduct {
        WasmClient.ShoppingProduct(
            title: p.hasTitle ? p.title : "",
            price: p.hasPrice ? p.price : nil,
            currency: p.hasCurrency ? p.currency : nil,
            url: p.hasURL ? p.url : "",
            image: p.hasImage ? p.image : nil,
            source: p.hasSource ? p.source : nil,
            rating: p.hasRating ? p.rating : nil,
            reviewsCount: p.hasReviewsCount ? Int(p.reviewsCount) : nil
        )
    }

    private static func mapLink(_ l: VisionLink) -> WasmClient.Link {
        WasmClient.Link(
            title: l.hasTitle ? l.title : "",
            url: l.hasURL ? l.url : "",
            description: l.hasDescription_p ? l.description_p : nil,
            image: l.hasImage ? l.image : nil
        )
    }
}
