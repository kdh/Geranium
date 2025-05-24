//
//  LocSimView.swift
//  Geranium
//
//  Created by cclerc on 21.12.23.
//

import SwiftUI
import CoreLocation
import AlertKit
import MapKit // Import MapKit

struct LocSimView: View {
    @StateObject private var appSettings = AppSettings()
    
    @State private var locationManager = CLLocationManager()
    @State private var lat: Double = 0.0
    @State private var long: Double = 0.0
    @State private var tappedCoordinate: EquatableCoordinate? = nil
    @State private var bookmarkSheetTggle: Bool = false
    
    // State variables for search
    @State private var searchText: String = ""
    @State private var searchResults: [CLPlacemark] = []
    @State private var isSearching: Bool = false
    @State private var searchError: String? = nil
    
    private let geocoder = CLGeocoder() // Add CLGeocoder instance
    
    var body: some View {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    LocSimMainView()
                }
            } else {
                NavigationView {
                    LocSimMainView()
                }
            }
        }
    @ViewBuilder
        private func LocSimMainView() -> some View {
            VStack { // Outer VStack
                // Search UI
                HStack {
                    TextField("Search by place name or address", text: $searchText)
                        .padding(.leading)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    
                    if !searchText.isEmpty {
                        Button(action: {
                            searchText = ""
                            searchResults = []
                            searchError = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                        .padding(.trailing)
                    }
                }
                .padding(.top)

                if isSearching {
                    ProgressView()
                        .padding()
                } else if let error = searchError {
                    Text(error)
                        .foregroundColor(.red)
                        .padding()
                } else if !searchResults.isEmpty {
                    List(searchResults, id: \.self) { placemark in
                        VStack(alignment: .leading) {
                            Text(placemark.name ?? "Unknown place")
                            Text("\(placemark.locality ?? ""), \(placemark.administrativeArea ?? "")")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .contentShape(Rectangle()) // Ensure the whole area is tappable
                        .onTapGesture {
                            // Dismiss Search UI
                            self.searchResults = []
                            self.searchText = ""
                            self.searchError = nil
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) // Dismiss keyboard

                            // Extract CLLocation
                            guard let location = placemark.location else {
                                self.searchError = "선택한 위치에 좌표 정보가 없습니다." // "Selected location has no coordinate information."
                                print("Error: Selected placemark has no location information.")
                                return
                            }

                            // Call LocSimManager.startLocSim()
                            LocSimManager.startLocSim(location: location)

                            // Update LocSimView's lat and long State Variables
                            self.lat = location.coordinate.latitude
                            self.long = location.coordinate.longitude

                            // Display "Started!" Confirmation Alert
                            AlertKitAPI.present(
                                title: "Started !",
                                icon: .done,
                                style: .iOS17AppleMusic,
                                haptic: .success
                            )
                        }
                    }
                    .frame(maxHeight: 200) // Adjust height as needed
                    .listStyle(PlainListStyle())
                }
                
                // Existing MapView VStack
                VStack {
                    CustomMapView(tappedCoordinate: $tappedCoordinate)
                        .onAppear {
                            CLLocationManager().requestAlwaysAuthorization()
                        }
                }
                .ignoresSafeArea(.keyboard)
            } // End of Outer VStack
            .onChange(of: searchText) { newValue in // Debounce search
                // Cancel previous task if any
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(performSearchWrapper), object: nil)
                // Schedule new search if searchText is not empty
                if !newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    perform(#selector(performSearchWrapper), with: nil, afterDelay: 0.5)
                } else {
                    // Clear results if search text is empty
                    searchResults = []
                    searchError = nil
                }
            }
        .onAppear { // This onAppear should ideally be on the outer VStack if it's for the whole view
            LocationModel().requestAuthorisation()
        }
        .onChange(of: tappedCoordinate) { newValue in
            if let coordinate = newValue {
                lat = coordinate.coordinate.latitude
                long = coordinate.coordinate.longitude
                LocSimManager.startLocSim(location: .init(latitude: lat, longitude: long))
                AlertKitAPI.present(
                    title: "Started !",
                    icon: .done,
                    style: .iOS17AppleMusic,
                    haptic: .success
                )
            }
        }
        .toolbar{
            ToolbarItem(placement: .navigationBarLeading) {
                Text("LocSim")
                    .font(.title2)
                    .bold()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    UIApplication.shared.TextFieldAlert(
                        title: "Enter Coordinates",
                        message: "The location will be simulated on device\nPro tip: Press wherever on the map to move there.",
                        textFieldPlaceHolder: "Latitude",
                        secondTextFieldPlaceHolder: "Longitude"
                    ) { latText, longText in
                        if let latDouble = Double(latText ?? ""), let longDouble = Double(longText ?? "") {
                            lat = latDouble
                            long = longDouble
                            LocSimManager.startLocSim(location: .init(latitude: latDouble, longitude: longDouble))
                        } else {
                            UIApplication.shared.alert(body: "Those are invalid coordinates mate !")
                        }
                    }
                }) {
                    Image(systemName: "mappin")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    if appSettings.locSimMultipleAttempts {
                        var countdown = appSettings.locSimAttemptNB
                        DispatchQueue.global().async {
                            while countdown > 0 {
                                LocSimManager.stopLocSim()
                                countdown -= 1
                            }
                        }
                    }
                    else {
                        LocSimManager.stopLocSim()
                    }
                    AlertKitAPI.present(
                        title: "Stopped !",
                        icon: .done,
                        style: .iOS17AppleMusic,
                        haptic: .success
                    )
                }) {
                    Image(systemName: "location.slash")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    bookmarkSheetTggle.toggle()
                }) {
                    Image(systemName: "bookmark")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                }
            }
        }
        .sheet(isPresented: $bookmarkSheetTggle) {
            BookMarkSlider(lat: $lat, long: $long)
        }
    }

    // Needs to be @objc for perform(#selector...)
    @objc private func performSearchWrapper() {
        performSearch(query: searchText)
    }

    private func performSearch(query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            searchResults = []
            searchError = nil
            isSearching = false
            return
        }

        isSearching = true
        searchError = nil
        searchResults = [] // Clear previous results as per current subtask instruction

        geocoder.geocodeAddressString(trimmedQuery) { placemarks, error in
            DispatchQueue.main.async {
                self.isSearching = false
                if let error = error as? CLError {
                    switch error.code {
                    case .geocodeNotFound, .geocodeFoundNoResult, .geocodeFoundPartialResult:
                        self.searchError = "검색 결과가 없습니다."
                    case .network:
                        self.searchError = "네트워크 오류가 발생했습니다. 인터넷 연결을 확인해주세요."
                    default:
                        self.searchError = "알 수 없는 오류로 검색에 실패했습니다: \(error.localizedDescription)"
                    }
                    self.searchResults = []
                    return
                }

                if let placemarks = placemarks, !placemarks.isEmpty {
                    self.searchResults = placemarks
                    self.searchError = nil
                } else {
                    self.searchError = "검색 결과가 없습니다."
                    self.searchResults = []
                }
            }
        }
    }
}
