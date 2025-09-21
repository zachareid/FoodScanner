import Foundation

struct FoodProduct: Identifiable, Equatable {
    struct Nutriments: Equatable {
        let energyKcalPer100g: Double?
        let fat: Double?
        let saturatedFat: Double?
        let carbohydrates: Double?
        let sugars: Double?
        let fiber: Double?
        let proteins: Double?
        let salt: Double?
    }

    struct NutriScore: Equatable {
        let grade: String
        let score: Int?

        var displayGrade: String { grade.uppercased() }
    }

    let id: String
    let barcode: String
    let name: String
    let brand: String?
    let quantity: String?
    let servingSize: String?
    let nutriments: Nutriments
    let nutriScore: NutriScore?
    let ecoScore: String?
    let novaGroup: Int?
    let categories: [String]
    let ingredients: String?
    let allergens: [String]
    let imageURL: URL?
}

extension FoodProduct {
    var displayName: String {
        if let brand, !brand.isEmpty {
            return "\(brand) – \(name)"
        }
        return name
    }

    var formattedCategories: String? {
        let cleaned = categories
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return cleaned.isEmpty ? nil : cleaned.joined(separator: ", ")
    }

    var hasNutrimentData: Bool {
        nutriments.energyKcalPer100g != nil ||
        nutriments.fat != nil ||
        nutriments.saturatedFat != nil ||
        nutriments.carbohydrates != nil ||
        nutriments.sugars != nil ||
        nutriments.fiber != nil ||
        nutriments.proteins != nil ||
        nutriments.salt != nil
    }
}
