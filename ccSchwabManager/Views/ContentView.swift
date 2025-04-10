//
//  ContentView.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-03-26.
//

import SwiftUI
import SwiftData

struct ContentView: View
{
    @State var m_secrets : Secrets
    @State var positionStatementData: [PositionStatementData] = []


    init()
    {
        m_secrets           = KeychainManager.readSecrets( prefix: "init/firstPass" ) ?? Secrets()
        //print( "ContentView - init(): m_secrets=\(m_secrets.dump())" )
    }

    var body: some View
    {
        TabView
        {
            KeychainView(  secrets: m_secrets )
                .tabItem {
                    Label("Keychain", systemImage: "lock.circle")
                }
            SalesCalcView( positionStatementData: $positionStatementData )
                .tabItem {
                    Label("Sales Calc", systemImage: "dollarsign.circle")
                }
            PositionStatementView( positionStatementData: $positionStatementData )
                .tabItem {
                    Label("Position Statement", systemImage: "doc.text")
                }
        }
        .onAppear {
            let url = Bundle.main.url(forResource: "PositionStatement", withExtension: "csv")
            positionStatementData = parseCSV(url: url)
        }
    }

} // ContentView



#Preview {
    ContentView()
}
