import Foundation

struct StationService {
    typealias SearchFilters = AVRadioStationSearchFilters

    private let service: AVRadioStationService

    init(session: URLSession = .shared) {
        self.service = AVRadioStationService(session: session)
    }

    func searchStations(filters: SearchFilters) async throws -> [Station] {
        try await service.searchStations(filters: filters)
    }
}
