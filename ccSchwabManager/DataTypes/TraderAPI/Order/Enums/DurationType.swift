//
//  DurationType.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-05-24.
//
/**

durationstring
Enum:
[ DAY, GOOD_TILL_CANCEL, FILL_OR_KILL, IMMEDIATE_OR_CANCEL, END_OF_WEEK, END_OF_MONTH, NEXT_END_OF_MONTH, UNKNOWN ]
*/

import Foundation

public enum DurationType : String, Codable, CaseIterable
{
    case DAY = "DAY"
    case GOOD_TILL_CANCEL = "GOOD_TILL_CANCEL"
    case FILL_OR_KILL = "FILL_OR_KILL"
    case IMMEDIATE_OR_CANCEL = "IMMEDIATE_OR_CANCEL"
    case END_OF_WEEK = "END_OF_WEEK"
    case END_OF_MONTH = "END_OF_MONTH"
    case NEXT_END_OF_MONTH = "NEXT_END_OF_MONTH"
    case UNKNOWN = "UNKNOWN"
}
