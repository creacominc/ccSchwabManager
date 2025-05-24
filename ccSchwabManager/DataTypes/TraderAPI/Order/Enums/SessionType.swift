//
//  SessionType.swift
//  ccSchwabManager
//
// [ NORMAL, AM, PM, SEAMLESS ]

import Foundation

public enum SessionType: String, Codable, CaseIterable
{
    case NORMAL = "NORMAL"
    case AM = "AM"
    case PM = "PM"
    case SEAMLESS = "SEAMLESS"
}

