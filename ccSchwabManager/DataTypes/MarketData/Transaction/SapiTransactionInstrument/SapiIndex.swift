//
//  SapiIndex.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-28.
//

import Foundation

/**
 SapiIndex{
 activeContract    boolean default: false
 type    SapiIndexType
 }
 */

public struct SapiIndex: Codable
{
    var activeContract: Bool = false
    var type: SapiIndexType
}
