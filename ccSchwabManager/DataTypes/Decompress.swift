//
//  Decompress.swift
//  ccSchwabManager
//
//  Created by Harold Tomlinson on 2025-04-20.
//


import Foundation
import zlib

func gunzip(data: Data) -> Data? {
    let bufferSize : Int = 64 * 1024 // Define a 64 KB buffer size
    var decompressedData = Data()
    var stream = z_stream()

    // print size of data
    print( "Data size: \(data.count) bytes" )

    // Initialize the z_stream structure for Gzip decoding
    guard inflateInit2_( &stream, MAX_WBITS + 32, ZLIB_VERSION, CInt(MemoryLayout<z_stream>.size) ) == Z_OK else {
        print( "Failed call to inflateInit2_" )
        return nil
    }
    defer { inflateEnd(&stream) }
    
    // Configure the input data for the zlib stream
    data.withUnsafeBytes { (compressedBytes: UnsafeRawBufferPointer) in
        guard let compressedPointer = compressedBytes.baseAddress?.assumingMemoryBound(to: Bytef.self) else {
            return
        }
        stream.next_in = UnsafeMutablePointer(mutating: compressedPointer)
        stream.avail_in = uInt(data.count)
    }
    
    // Decompression loop
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
    defer { buffer.deallocate() }
    
    repeat {
        stream.next_out = buffer
        stream.avail_out = uInt(bufferSize)
        print( "stream.avail_out: \(stream.avail_out)" )

        let status = inflate(&stream, Z_NO_FLUSH)
        print( "status: \(status)" )

        // Check for errors or end of stream
        if status == Z_STREAM_END {
            let outputSize = bufferSize - Int(stream.avail_out)
            decompressedData.append(buffer, count: outputSize)
            print( "end of stream.  appended \(outputSize) bytes" )
            break
        } else if status != Z_OK {
            print( "decompression failed" )
            return nil // Decompression failed
        }
        
        let outputSize = bufferSize - Int(stream.avail_out)
        decompressedData.append(buffer, count: outputSize)
        print( "appended \(outputSize) bytes" )
    } while stream.avail_out == 0
    
//    // Convert the decompressed Data to a String
//    return String(data: decompressedData, encoding: .utf8)
    return decompressedData
}
