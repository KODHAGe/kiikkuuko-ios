//
//  ContentView.swift
//  kiikkuuko
//
//  Created by Wolf Wikgren on 22.10.2023.
//

import SwiftUI
import CoreLocation
import MapKit

struct Unit: Codable, Identifiable {
    let id: Int
    let organizerType: String?
    let contractType: ContractType
    let name: LocalizedText
    let streetAddress: LocalizedText
    let municipality: String
    let serviceNodes: [ServiceNode]
    let location: Location?
    let geometry: Geometry?
    let department: Department
    let rootDepartment: RootDepartment
    let services: [Service]
    let accessibilityProperties: [AccessibilityProperty]?
    let accessibilityShortcomingCount: AccessibilityShortcomingCount?
    var distance: CLLocationDistance?
    var isFavorite: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, name, municipality, location, geometry, department, services
        case organizerType = "organizer_type"
        case contractType = "contract_type"
        case streetAddress = "street_address"
        case serviceNodes = "service_nodes"
        case rootDepartment = "root_department"
        case accessibilityProperties = "accessibility_properties"
        case accessibilityShortcomingCount = "accessibility_shortcoming_count"
    }
}

struct ContractType: Codable {
    let id: String
    let description: LocalizedText
}

struct LocalizedText: Codable, Hashable {
    let fi: String
}

struct ServiceNode: Codable {
    let id: Int
    let name: LocalizedText
    let root: Int
    let service_reference: String
    let level: Int
}

struct Location: Codable {
    let type: String?
    let coordinates: [Double]?
}

struct Geometry: Codable {
    let type: String?
    let coordinates: [Double]?
}

struct Department: Codable {
    let id: String
    let name: LocalizedText
    let street_address: LocalizedText?
    let municipality: String
}

struct RootDepartment: Codable {
    let id: String
    let name: LocalizedText
    let street_address: LocalizedText?
    let municipality: String
}

struct Service: Codable {
    let clarification: String?
    let name: LocalizedText
    let root_service_node: Int
    let id: Int
}

struct AccessibilityProperty: Codable {
}

struct AccessibilityShortcomingCount: Codable {
}

struct Response: Codable {
    let count: Int
    let next: String?
    let previous: String?
    let results: [Unit]
}

struct ContentView: View {
    
    var FontLarge : Font = Font.custom("DotGothic16-Regular", size: 32)
    var FontRegular : Font = Font.custom("DotGothic16-Regular", size: 16)
    var FontSmall : Font = Font.custom("DotGothic16-Regular", size: 12)

   init() {
        //Use this if NavigationBarTitle is with Large Font
        //UINavigationBar.appearance().largeTitleTextAttributes = [.font : UIFont(name: "Georgia-Bold", size: 20)!]

        //Use this if NavigationBarTitle is with displayMode = .inline
        UINavigationBar.appearance().titleTextAttributes = [.font : UIFont(name: "DotGothic16-Regular", size: 24)!]
        UITabBarItem.appearance().setTitleTextAttributes([.font : UIFont(name: "DotGothic16-Regular", size: 12)!], for: [])
        UITabBarItem.appearance().setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
    }
    
    @ObservedObject private var locationManagerWrapper = LocationManager()

    @State private var units: [Unit] = []
    @State private var isLoading = false
    @State private var userLatitude: Double = 0
    @State private var userLongitude: Double = 0
    @State private var Kiikkuuko : String = ""
    @State private var selectedUnitId: Int?
    
    private let apiUrl = "https://api.hel.fi/servicemap/v2/unit/?format=json&geometry=true&include=service_nodes%2Cservices%2Caccessibility_properties%2Cdepartment%2Croot_department&language=fi&only=street_address%2Clocation%2Cname%2Cmunicipality%2Caccessibility_shortcoming_count%2Cservice_nodes%2Ccontract_type%2Corganizer_type&page=1&page_size=1000&service_node=499"

    var sortedUnits: [Unit] {
        guard let userLocation = locationManagerWrapper.userLocation else {
            return units // Return original order if user location is not available
        }
        
        var unitsWithDistance = units
        
        for index in 0..<unitsWithDistance.count {
            let unit = unitsWithDistance[index]
            guard let unitCoordinates = unit.location?.coordinates else {
                continue // Skip units with missing location
            }
            
            let unitLocation = CLLocation(latitude: unitCoordinates[1], longitude: unitCoordinates[0])
            let distance = userLocation.distance(from: unitLocation)
            unitsWithDistance[index].distance = distance
        }
        
        unitsWithDistance = unitsWithDistance.filter { $0.location != nil }

        let favorites = loadFavorites()
        
        return unitsWithDistance
            .sorted { $0.distance ?? 0 < $1.distance ?? 0 }
            .map { unit in
                var updatedUnit = unit
                updatedUnit.isFavorite = unit.isFavorite || favorites.contains(unit.id)
                return updatedUnit
            }
    }

    var body: some View {
        TabView {
            // List Tab
            NavigationView {
                VStack() {
                    Image(Kiikkuuko)
                    .resizable()
                    .frame(width: 32, height: 32, alignment: .center)
                    .onAppear(perform: animationTimer)
                    List(sortedUnits, id: \.name.fi) { unit in
                        VStack(alignment: .leading) {
                            HStack(content: {
                                VStack(alignment: .leading, content: {
                                    Text(unit.name.fi).font(FontRegular)
                                    if let distance = unit.distance {
                                        Text("Etäisyys: \(String(format: "%.2f kilometriä", distance/1000))")
                                            .font(FontSmall)
                                    }
                                })
                                Spacer()
                                Button(action: {
                                    storeFavorite(unit.id)
                                }) {
                                    VStack(spacing: 1, content: {
                                        Image(unit.isFavorite ? "star2" : "star1")
                                            .resizable()
                                            .frame(width: 32, height: 32, alignment: .center)
                                        Text("Käyty").font(FontSmall)
                                    })
                                }.buttonStyle(MyButtonStyle())
                                Button(action: {
                                    openMapsNavigation(coordinates: unit.location?.coordinates)
                                }) {
                                    VStack(spacing: 1,content: {
                                        Image("arrow")
                                            .resizable()
                                            .frame(width: 32, height: 32, alignment: .center)
                                        Text("Reitti").font(FontSmall)
                                    })
                                }.buttonStyle(MyButtonStyle())
                            })
                        }
                    }
                }
                .navigationBarTitle("Kiikkuuko?", displayMode: .inline)
            }
            .tabItem {
                Label("Lista", image: "menu").font(FontRegular)
            }
            .onAppear {
                //fetchDataFromStaticFile() // Fetch data from static file first
                // fetchDataFromAPI() 
            }
            .environmentObject(locationManagerWrapper) // Add reference to LocationManager
            .onReceive(locationManagerWrapper.$userLocation) { location in
                if let location = location {
                    userLatitude = location.coordinate.latitude
                    userLongitude = location.coordinate.longitude
                }
            }
            
            // Map Tab
            Map(coordinateRegion: $locationManagerWrapper.region,showsUserLocation: true, annotationItems: sortedUnits) { unit in
                MapAnnotation(coordinate: CLLocationCoordinate2D(latitude: unit.location?.coordinates?[1] ?? 0, longitude: unit.location?.coordinates?[0] ?? 0)) {
                    if(selectedUnitId == unit.id) {
                        Text(unit.name.fi).font(FontRegular)
                    }
                    if(unit.isFavorite) {
                        Image("star2").resizable().frame(width: 32, height: 32, alignment: .center)
                            .onTapGesture {
                                selectedUnitId = unit.id
                            }
                    } else {
                        Image("kiikkuuko1").resizable().frame(width: 32, height: 32, alignment: .center)
                            .onTapGesture {
                                selectedUnitId = unit.id
                            }
                    }
                    if(selectedUnitId == unit.id) {
                        Button(action: {
                            openMapsNavigation(coordinates: unit.location?.coordinates)
                        }) {
                            Image("arrow").resizable().frame(width: 32, height: 32, alignment: .center)
                        }
                    }
                }
            }
            .edgesIgnoringSafeArea(.all)
            .onAppear {
            }
            .tabItem {
                Label {
                    Text("Kartta").font(FontSmall)
                } icon: {
                    Image("map")
                        .resizable()
                        .scaledToFit()
                }
            }
            }
        .onAppear {
            fetchDataFromStaticFile() // Fetch data from static file first
            // fetchDataFromAPI() // Then fetch data from the API
        }
        .environmentObject(locationManagerWrapper) // Add reference to LocationManager
        .onReceive(locationManagerWrapper.$userLocation) { location in
            if let location = location {
                userLatitude = location.coordinate.latitude
                userLongitude = location.coordinate.longitude
            }
        }
    }

    // Fetch data from static file
    private func fetchDataFromStaticFile() {
        if let dataAsset = NSDataAsset(name: "StaticData") {
            do {
                let data = dataAsset.data
                let decoder = JSONDecoder()
                let jsonData = try decoder.decode(Response.self, from: data)
                DispatchQueue.main.async {
                    units = jsonData.results
                }
            } catch {
                print("Error decoding static data: \(error.localizedDescription)")
            }
        } else {
            print("Static JSON file not found.")
        }
    }


        // Function to open Apple Maps with pedestrian routing
    private func openMapsNavigation(coordinates: [Double]?) {
        guard let coordinates = coordinates,
            coordinates.count == 2 else {
            return
        }
        
        let latitude = coordinates[1]
        let longitude = coordinates[0]

        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let destinationPlacemark = MKPlacemark(coordinate: coordinate)
        let destinationMapItem = MKMapItem(placemark: destinationPlacemark)
        destinationMapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    // Fetch data from API
    private func fetchDataFromAPI() {
        guard let url = URL(string: apiUrl) else {
            print("Invalid URL.")
            return
        }

        isLoading = true

        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                isLoading = false
                return
            }

            guard let data = data else {
                print("No data received.")
                isLoading = false
                return
            }

            do {
                let decoder = JSONDecoder()
                let apiResponse = try decoder.decode(Response.self, from: data)

                DispatchQueue.main.async {
                    if units.count != apiResponse.count {
                        units = apiResponse.results
                    }
                    isLoading = false
                }
            } catch {
                print("Error decoding data: \(error.localizedDescription)")
                isLoading = false
            }
        }.resume()
    }

    private func animationTimer(){     
    var index = 1
    _ = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { (Timer) in
            
        Kiikkuuko = "kiikkuuko\(index)"
            
        index += 1
            
        if (index > 4){
            index = 1
            
            }
        }
    }
    
    func recalculateDistances(userLocation: CLLocation?) {
        if let userLocation = userLocation {
            for index in 0..<units.count {
                let unit = units[index]
                guard let unitCoordinates = unit.location?.coordinates else {
                    continue // Skip units with missing location
                }
                
                let unitLocation = CLLocation(latitude: unitCoordinates[1], longitude: unitCoordinates[0])
                let distance = userLocation.distance(from: unitLocation)
                units[index].distance = distance
            }
        }
    }

    func storeFavorite(_ unitId: Int) {
        if var unit = units.first(where: { $0.id == unitId }) {
            unit.isFavorite.toggle()
            DispatchQueue.main.async {
                // Update units array to reflect the favorite status change
                units = units.map { $0.id == unitId ? unit : $0 }
                storeFavorites()
            }
        }
    }

    func loadFavorites() -> [Int] {
        if let favorites = UserDefaults.standard.array(forKey: "Favorites") as? [Int] {
            return favorites
        }
        return []
    }

    private func storeFavorites() {
        let favorites = units.filter { $0.isFavorite }.map { $0.id }
        UserDefaults.standard.set(favorites, forKey: "Favorites")
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
    ContentView()
        .onAppear {
        }
    }
}

class LocationManager: NSObject, CLLocationManagerDelegate, ObservableObject {
    let locationManager = CLLocationManager()
    @Published var userLocation: CLLocation?
    @Published var region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 38.898150, longitude: -77.034340),
        span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
    )
    private var hasSetRegion = false
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        userLocation = locations.last
        if !hasSetRegion {
            self.region = MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: userLocation?.coordinate.latitude ?? 0, longitude: userLocation?.coordinate.longitude ?? 0), span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05))
            hasSetRegion = true
        }
        // Recalculate unit distances whenever user location updates
        DispatchQueue.main.async {
            ContentView().recalculateDistances(userLocation: locations.last)
        }
    }
}

extension CLLocation {
    func distance(from coordinate: CLLocationCoordinate2D) -> CLLocationDistance {
        let coordinateLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return distance(from: coordinateLocation)
    }
}

  struct MyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
      configuration.label
        .foregroundColor(.black)
        .opacity(configuration.isPressed ? 0.5 : 1.0)
    }
  }
