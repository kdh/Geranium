import SwiftUI
import MapKit
import AlertKit

struct LocationSearchView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var lat: Double
    @Binding var long: Double
    @State private var query = ""
    @State private var results: [MKMapItem] = []

    var body: some View {
        NavigationView {
            List(results, id: \.self) { item in
                Button(action: {
                    lat = item.placemark.coordinate.latitude
                    long = item.placemark.coordinate.longitude
                    LocSimManager.startLocSim(location: .init(latitude: lat, longitude: long))
                    AlertKitAPI.present(
                        title: "Started !",
                        icon: .done,
                        style: .iOS17AppleMusic,
                        haptic: .success
                    )
                    dismiss()
                }) {
                    VStack(alignment: .leading) {
                        Text(item.name ?? "Unknown")
                            .font(.headline)
                        Text(item.placemark.title ?? "")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
            .searchable(text: $query, prompt: "Search location")
            .onChange(of: query) { newValue in
                performSearch()
            }
            .navigationTitle("Search")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("Search")
                        .font(.title2)
                        .bold()
                }
            }
        }
    }

    private func performSearch() {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        let search = MKLocalSearch(request: request)
        search.start { response, error in
            if let items = response?.mapItems {
                self.results = items
            } else {
                self.results = []
            }
        }
    }
}
