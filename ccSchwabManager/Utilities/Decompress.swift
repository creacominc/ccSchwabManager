//
//  Decompress.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-20.
//

import zlib
import Foundation
import Compression

func decompressGzip(data: Data) -> Data?
{
    print("Input data size: \(data.count)")
    print("Input data (base64): \(data.base64EncodedString())")

    // Initialize zlib stream
    var stream = z_stream()
    stream.avail_in = uInt(data.count)

    // Use withUnsafeBytes to get a pointer to the input data
    data.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) in
        stream.next_in = UnsafeMutablePointer<Bytef>(mutating: rawBufferPointer.bindMemory(to: Bytef.self).baseAddress)
    }

    // Allocate output buffer
    let bufferSize = 64 * 1024 // 64 KB
    var outputData = Data()
    let outputBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { outputBuffer.deallocate() }

    // Initialize the zlib stream for GZIP decompression using inflateInit2_
    let windowBits = 16 + MAX_WBITS // Enable GZIP decoding
    let result = inflateInit2_(&stream, windowBits, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size))
    guard result == Z_OK else {
        print("Failed to initialize zlib stream with error code: \(result)")
        return nil
    }
    defer { inflateEnd(&stream) } // Ensure cleanup

    // Decompress the data
    var status: Int32
    repeat {
        stream.next_out = outputBuffer
        stream.avail_out = uInt(bufferSize)

        status = inflate(&stream, Z_SYNC_FLUSH)
        switch status {
        case Z_OK, Z_STREAM_END:
            let outputBytes = bufferSize - Int(stream.avail_out)
            outputData.append(outputBuffer, count: outputBytes)
        default:
            print("Decompression failed with status: \(status)")
            return nil
        }
    } while status == Z_OK

    return status == Z_STREAM_END ? outputData : nil
}



