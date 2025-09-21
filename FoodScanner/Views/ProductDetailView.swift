import SwiftUI

struct ProductDetailView: View {
    let product: FoodProduct

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            productHero
            nutritionSection
            ingredientSection
            allergenSection
        }
    }

    private var productHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let url = product.imageURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .clipped()
                            .cornerRadius(12)
                    case .failure:
                        placeholderImage
                    @unknown default:
                        placeholderImage
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(product.displayName)
                    .font(.title2)
                    .fontWeight(.semibold)

                if let quantity = product.quantity, !quantity.isEmpty {
                    Text(quantity)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let serving = product.servingSize, !serving.isEmpty {
                    Text("Serving size: \(serving)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if let categories = product.formattedCategories {
                    Text(categories)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 8) {
                if let nutriScore = product.nutriScore {
                    NutriScoreBadge(grade: nutriScore.displayGrade, score: nutriScore.score)
                }

                if let ecoScore = product.ecoScore, !ecoScore.isEmpty {
                    TagView(title: "Eco score", value: ecoScore.uppercased())
                }

                if let nova = product.novaGroup {
                    TagView(title: "NOVA", value: "\(nova)")
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var nutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Nutrition per 100g")
                .font(.headline)

            if nutritionFacts.isEmpty {
                Text("No nutrition facts available yet.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 12) {
                    ForEach(nutritionFacts, id: \.label) { fact in
                        HStack {
                            Text(fact.label)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(fact.value)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var ingredientSection: some View {
        Group {
            if let ingredients = product.ingredients, !ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ingredients")
                        .font(.headline)
                    Text(ingredients)
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private var allergenSection: some View {
        Group {
            if !product.allergens.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Allergens")
                        .font(.headline)
                    Text(product.allergens.joined(separator: ", "))
                        .font(.body)
                        .foregroundStyle(.primary)
                }
            }
        }
    }

    private var nutritionFacts: [NutritionFactDisplay] {
        var items: [NutritionFactDisplay] = []
        let nutriments = product.nutriments

        func add(_ label: String, value: Double?, unit: String) {
            guard let value else { return }
            items.append(NutritionFactDisplay(label: label, value: "\(value.formatted()) \(unit)"))
        }

        add("Energy", value: nutriments.energyKcalPer100g, unit: "kcal")
        add("Fat", value: nutriments.fat, unit: "g")
        add("Saturated fat", value: nutriments.saturatedFat, unit: "g")
        add("Carbohydrates", value: nutriments.carbohydrates, unit: "g")
        add("Sugars", value: nutriments.sugars, unit: "g")
        add("Fiber", value: nutriments.fiber, unit: "g")
        add("Proteins", value: nutriments.proteins, unit: "g")
        add("Salt", value: nutriments.salt, unit: "g")
        return items
    }

    private var placeholderImage: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.2))
            .overlay {
                Image(systemName: "cart")
                    .imageScale(.large)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 180)
    }
}

private struct NutritionFactDisplay: Hashable {
    let label: String
    let value: String
}

private struct TagView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.footnote)
                .fontWeight(.semibold)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(.thinMaterial)
        .clipShape(Capsule())
    }
}

private struct NutriScoreBadge: View {
    let grade: String
    let score: Int?

    var body: some View {
        HStack(spacing: 6) {
            Text("Nutri-Score")
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(grade)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(textColor(for: grade))
            if let score {
                Text("\(score)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(color(for: grade))
        .clipShape(Capsule())
    }

    private func color(for grade: String) -> Color {
        switch grade.lowercased() {
        case "a": return Color.green.opacity(0.2)
        case "b": return Color.green.opacity(0.15)
        case "c": return Color.yellow.opacity(0.25)
        case "d": return Color.orange.opacity(0.25)
        case "e": return Color.red.opacity(0.25)
        default: return Color.gray.opacity(0.2)
        }
    }

    private func textColor(for grade: String) -> Color {
        switch grade.lowercased() {
        case "a": return .green
        case "b": return .green
        case "c": return .orange
        case "d": return .orange
        case "e": return .red
        default: return .primary
        }
    }
}

private extension Double {
    func formatted() -> String {
        if self >= 100 || self.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", self)
        }
        return String(format: "%.1f", self)
    }
}

#Preview {
    let product = FoodProduct(
        id: "123456789",
        barcode: "123456789",
        name: "Organic Apple Juice",
        brand: "Nature's Best",
        quantity: "1L",
        servingSize: "250ml",
        nutriments: .init(
            energyKcalPer100g: 45,
            fat: 0.2,
            saturatedFat: 0.1,
            carbohydrates: 10.5,
            sugars: 9.1,
            fiber: 1.2,
            proteins: 0.5,
            salt: 0.05
        ),
        nutriScore: .init(grade: "B", score: 24),
        ecoScore: "B",
        novaGroup: 1,
        categories: ["Beverages", "Juices"],
        ingredients: "Apple juice from concentrate.",
        allergens: [],
        imageURL: nil
    )

    return ProductDetailView(product: product)
        .padding()
}
