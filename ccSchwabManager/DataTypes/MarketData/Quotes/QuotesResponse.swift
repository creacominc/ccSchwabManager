//
//  QuotesResponse.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-01-11.
//

import Foundation
import SwiftData

//@Model
public struct QuotesResponse : Codable
{

//    init(m_symbol: SapiSymbol, m_fundamental: SapiFundamental, m_quote: SapiQuote, m_reference: SapiReference, m_regular: SapiRegularMarket)
//    {
//        self.m_symbol = m_symbol
//        self.m_fundamental = m_fundamental
//        self.m_quote = m_quote
//        self.m_reference = m_reference
//        self.m_regular = m_regular
//    }

    private var m_symbol: SapiSymbol
    private var m_fundamental: SapiFundamental
    private var m_quote: SapiQuote
    private var m_reference: SapiReference
    private var m_regular: SapiRegularMarket

}

