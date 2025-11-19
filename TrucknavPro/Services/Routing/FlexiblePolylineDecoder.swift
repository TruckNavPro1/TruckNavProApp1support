//
//  FlexiblePolylineDecoder.swift
//  TruckNavPro
//
//  Decodes HERE Flexible Polyline format.
//  Reference: https://github.com/heremaps/flexible-polyline
//

import Foundation
import CoreLocation

class FlexiblePolylineDecoder {
    
    private static let encodingTable: [Character] = [
        "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P","Q","R","S","T","U","V","W","X","Y","Z",
        "a","b","c","d","e","f","g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v","w","x","y","z",
        "0","1","2","3","4","5","6","7","8","9","-","_"
    ]
    
    private static let decodingTable: [Int] = {
        var table = Array(repeating: -1, count: 128)
        for (index, char) in encodingTable.enumerated() {
            if let ascii = char.asciiValue {
                table[Int(ascii)] = index
            }
        }
        return table
    }()
    
    /// Decodes a HERE Flexible Polyline string into an array of coordinates.
    /// - Parameter polyline: The encoded polyline string.
    /// - Returns: An array of CLLocationCoordinate2D.
    static func decode(polyline: String) -> [CLLocationCoordinate2D] {
        guard let data = polyline.data(using: .utf8) else { return [] }
        let bytes = [UInt8](data)
        var index = 0
        
        // Decode Header
        // Byte 0: Version (must be 1)
        guard index < bytes.count else { return [] }
        let version = decodeValue(bytes: bytes, index: &index)
        // We currently only support version 1 (which is actually not varint encoded in the spec, but let's check the char)
        // Actually, the spec says "The header is a list of values... The first value is the version."
        // But usually the version is just a simple check.
        // Let's follow the reference implementation logic more closely.
        // In the reference, the header is parsed to get precision.
        
        // However, for the sake of this fix and given the crash was in the Google decoder,
        // we will implement a robust decoder that handles the Flexible Polyline format.
        
        // Re-setting index to 0 to parse properly
        index = 0
        
        // Decode Header
        // 1. Version
        // 2. Precision (Z, M, etc.)
        // For simplicity, we assume standard 2D lat/lon encoding which is the default for routing.
        // If the header indicates 3D or other data, we need to skip it.
        
        // Let's use a simplified approach that works for standard HERE routing responses.
        // The header usually starts with a version char.
        
        // Decode header
        guard index < bytes.count else { return [] }
        
        // Helper to decode a single value
        func decodeVarInt() -> Int {
            var result = 0
            var shift = 0
            
            while index < bytes.count {
                let byte = bytes[index]
                index += 1
                
                guard let value = byteToValue(byte) else { return 0 }
                
                let operand = value & 0x1f
                result |= operand << shift
                shift += 5
                
                if (value & 0x20) == 0 {
                    break
                }
            }
            return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        }
        
        func decodeUnsignedVarInt() -> Int {
             var result = 0
             var shift = 0
             
             while index < bytes.count {
                 let byte = bytes[index]
                 index += 1
                 
                 guard let value = byteToValue(byte) else { return 0 }
                 
                 let operand = value & 0x1f
                 result |= operand << shift
                 shift += 5
                 
                 if (value & 0x20) == 0 {
                     break
                 }
             }
             return result
        }
        
        // Header parsing
        // Version is the first value (unsigned)
        let _ = decodeUnsignedVarInt() // Version
        
        // Value 2: Header properties (precision, 3rd dim, etc.)
        // We need to parse this to know how to decode the rest.
        // But for the crash fix, we can try to assume standard precision (5 decimals) if we can't parse fully.
        // Wait, the crash is due to using the WRONG decoder.
        // The HERE Flexible Polyline format is NOT compatible with Google's.
        
        // Let's implement a proper decoder based on the spec.
        // Header:
        // [version] [header]
        // version is always 1 (encoded as char)
        
        // Reset index to 0
        index = 0
        
        // Decode Header
        // 1. Version
        let _ = decodeUnsignedVarInt()
        
        // 2. Header spec
        let header = decodeUnsignedVarInt()
        
        // Parse header
        let precision = header & 15 // last 4 bits
        let thirdDim = (header >> 4) & 7 // next 3 bits
        let thirdDimPrecision = (header >> 7) & 15 // next 4 bits
        
        let multiplier = pow(10.0, Double(precision))
        let thirdDimMultiplier = pow(10.0, Double(thirdDimPrecision))
        
        var lastLat: Int = 0
        var lastLon: Int = 0
        var lastZ: Int = 0
        
        var coordinates: [CLLocationCoordinate2D] = []
        
        while index < bytes.count {
            // Decode Lat
            let deltaLat = decodeVarInt()
            lastLat += deltaLat
            
            // Decode Lon
            let deltaLon = decodeVarInt()
            lastLon += deltaLon
            
            // Decode Z if present
            if thirdDim != 0 {
                let deltaZ = decodeVarInt()
                lastZ += deltaZ
            }
            
            let lat = Double(lastLat) / multiplier
            let lon = Double(lastLon) / multiplier
            
            coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon))
        }
        
        return coordinates
    }
    
    private static func byteToValue(_ byte: UInt8) -> Int? {
        let intVal = Int(byte)
        if intVal >= 0 && intVal < 128 {
            return decodingTable[intVal]
        }
        return nil
    }
    
    private static func decodeValue(bytes: [UInt8], index: inout Int) -> Int {
        // Placeholder for more complex decoding if needed
        return 0
    }
    
    // Kept for compatibility but redirects to correct decoder if needed,
    // or we can just remove it if we update the caller.
    // The caller (HERERoutingService) was using this method name.
    // We will update the caller to use `decode` instead, but for safety we can keep this
    // and make it call `decode` if it detects Flexible Polyline format, or just use `decode`.
    // Given the crash, we should force the use of the correct decoder.
    
    static func decodeGooglePolyline(encodedPolyline: String, precision: Double = 1e5) -> [CLLocationCoordinate2D] {
        // Check if it looks like a Flexible Polyline (starts with alphanumeric usually)
        // Google Polylines often start with `_` or similar for high precision, but standard ones vary.
        // However, HERE v8 ALWAYS returns Flexible Polyline.
        return decode(polyline: encodedPolyline)
    }
}
