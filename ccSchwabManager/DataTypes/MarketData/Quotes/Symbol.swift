//
//  SapiSymbol.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-01-11.
//

import Foundation

public struct Symbol : Codable
{

//    init(m_assetType: AssetType, m_assetSubType: EquityAssetSubType, m_quoteType: QuoteType, m_realtime: Bool, m_ssid: Int, m_symbol: String, m_extended: SapiExtendedMarket)
//    {
//        self.m_assetType = m_assetType
//        self.m_assetSubType = m_assetSubType
//        self.m_quoteType = m_quoteType
//        self.m_realtime = m_realtime
//        self.m_ssid = m_ssid
//        self.m_symbol = m_symbol
//        self.m_extended = m_extended
//    }


    private var m_assetType: AssetType = AssetType.EQUITY
    private var m_assetSubType: EquityAssetSubType = EquityAssetSubType.COE
    private var m_quoteType: QuoteType = QuoteType.NBBO
    private var m_realtime: Bool = false
    private var m_ssid: Int = 0
    private var m_symbol: String = ""

    private var m_extended: ExtendedMarket


}


/**

 */
