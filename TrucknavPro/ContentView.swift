//
//  ContentView.swift
//  TruckNavPro
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationViewControllerRepresentable()
            .ignoresSafeArea()
    }
}

struct NavigationViewControllerRepresentable: UIViewControllerRepresentable {

    func makeUIViewController(context: Context) -> MapViewController {
        return MapViewController()
    }

    func updateUIViewController(_ uiViewController: MapViewController, context: Context) {
    }
}

#Preview {
    ContentView()
}
