import Foundation

struct OpenFoodFactsClient {
    enum ClientError: LocalizedError {
        case invalidBarcode
        case invalidURL
        case requestFailed(underlying: Error)
        case unexpectedStatusCode(Int)
        case decodingFailure(underlying: Error)
        case productNotFound

        var errorDescription: String? {
            switch self {
            case .invalidBarcode:
                return "That barcode doesn't look valid. Let's try another one."
            case .invalidURL:
                return "We couldn't build the product request."
            case .requestFailed(let underlying):
                return underlying.localizedDescription
            case .unexpectedStatusCode(let code):
                return "Open Food Facts returned an unexpected status code: \(code)."
            case .decodingFailure:
                return "We couldn't read the product details from Open Food Facts."
            case .productNotFound:
                return "We couldn't find this product in Open Food Facts yet."
            }
        }
    }

    private let session: URLSession
    private let baseURL = URL(string: "https://world.openfoodfacts.org")!

    init(session: URLSession = .shared) {
        self.session = session
    }

    func fetchProduct(barcode rawBarcode: String) async throws -> FoodProduct {
        let barcode = rawBarcode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !barcode.isEmpty else { throw ClientError.invalidBarcode }

        guard let url = URL(string: "/api/v2/product/\(barcode).json", relativeTo: baseURL) else {
            throw ClientError.invalidURL
        }

        var request = URLRequest(url: url)
        request.setValue("FoodScanner/1.0 (iOS)", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20

        let dataResponse: (Data, URLResponse)
        do {
            dataResponse = try await session.data(for: request)
        } catch {
            throw ClientError.requestFailed(underlying: error)
        }

        let (data, response) = dataResponse
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ClientError.unexpectedStatusCode(-1)
        }

        guard (200..<300).contains(httpResponse.statusCode) else {
            throw ClientError.unexpectedStatusCode(httpResponse.statusCode)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let apiResponse: ProductResponse
        do {
            apiResponse = try decoder.decode(ProductResponse.self, from: data)
        } catch {
            throw ClientError.decodingFailure(underlying: error)
        }

        guard apiResponse.status == 1, let apiProduct = apiResponse.product else {
            throw ClientError.productNotFound
        }

        return apiProduct.domainModel(defaultBarcode: barcode)
    }
}

private extension OpenFoodFactsClient {
    struct ProductResponse: Decodable {
        let status: Int
        let code: String
        let product: APIProduct?
    }

    struct APIProduct: Decodable {
        let code: String?
        let productName: String?
        let genericName: String?
        let brands: String?
        let categoriesTags: [String]?
        let ingredientsText: String?
        let allergensTags: [String]?
        let imageUrl: String?
        let quantity: String?
        let servingSize: String?
        let nutriscoreGrade: String?
        let nutriscoreScore: Int?
        let ecoscoreGrade: String?
        let novaGroup: Int?
        let nutriments: APINutriments?

        enum CodingKeys: String, CodingKey {
            case code
            case productName
            case genericName
            case brands
            case categoriesTags
            case ingredientsText
            case allergensTags
            case imageUrl
            case quantity
            case servingSize
            case nutriscoreGrade
            case nutriscoreScore
            case ecoscoreGrade
            case novaGroup
            case nutriments
        }
    }

    struct APINutriments: Decodable {
        let energyKcal100g: Double?
        let fat100g: Double?
        let saturatedFat100g: Double?
        let carbohydrates100g: Double?
        let sugars100g: Double?
        let fiber100g: Double?
        let proteins100g: Double?
        let salt100g: Double?

        enum CodingKeys: String, CodingKey {
            case energyKcal100g = "energy-kcal_100g"
            case fat100g = "fat_100g"
            case saturatedFat100g = "saturated-fat_100g"
            case carbohydrates100g = "carbohydrates_100g"
            case sugars100g = "sugars_100g"
            case fiber100g = "fiber_100g"
            case proteins100g = "proteins_100g"
            case salt100g = "salt_100g"
        }
    }
}

private extension OpenFoodFactsClient.APIProduct {
    func domainModel(defaultBarcode: String) -> FoodProduct {
        let primaryName = [productName, genericName, brands?.components(separatedBy: ",").first?.trimmed]
            .compactMap { $0?.trimmed }
            .first ?? defaultBarcode

        let displayBrand = brands?.components(separatedBy: ",")
            .compactMap { $0.trimmed }
            .first

        let categories: [String] = categoriesTags?.compactMap { tag in
            guard let raw = tag.split(separator: ":").last else { return nil }
            return raw.replacingOccurrences(of: "-", with: " ").capitalized
        } ?? []

        let allergens: [String] = allergensTags?.compactMap { tag in
            guard let raw = tag.split(separator: ":").last else { return nil }
            return raw.replacingOccurrences(of: "-", with: " ").capitalized
        } ?? []

        let imageURL = imageUrl.flatMap { URL(string: $0) }

        let nutriments = FoodProduct.Nutriments(
            energyKcalPer100g: nutriments?.energyKcal100g,
            fat: nutriments?.fat100g,
            saturatedFat: nutriments?.saturatedFat100g,
            carbohydrates: nutriments?.carbohydrates100g,
            sugars: nutriments?.sugars100g,
            fiber: nutriments?.fiber100g,
            proteins: nutriments?.proteins100g,
            salt: nutriments?.salt100g
        )

        let nutriScore: FoodProduct.NutriScore?
        if let grade = nutriscoreGrade?.trimmingCharacters(in: .whitespacesAndNewlines), !grade.isEmpty {
            nutriScore = FoodProduct.NutriScore(grade: grade, score: nutriscoreScore)
        } else {
            nutriScore = nil
        }

        return FoodProduct(
            id: code ?? defaultBarcode,
            barcode: code ?? defaultBarcode,
            name: primaryName,
            brand: displayBrand,
            quantity: quantity?.trimmed,
            servingSize: servingSize?.trimmed,
            nutriments: nutriments,
            nutriScore: nutriScore,
            ecoScore: ecoscoreGrade?.trimmed,
            novaGroup: novaGroup,
            categories: categories,
            ingredients: ingredientsText?.trimmed,
            allergens: allergens,
            imageURL: imageURL
        )
    }
}

private extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}
