import CryptoKit
import Foundation

nonisolated enum SHA256Digest {
    static func hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

nonisolated enum DeterministicZIP {
    static func make(files: [(name: String, data: Data)]) -> Data {
        var archive = Data()
        var centralDirectory = Data()
        var localOffset: UInt32 = 0

        for file in files.sorted(by: { $0.name < $1.name }) {
            let name = Data(file.name.utf8)
            let checksum = CRC32.checksum(file.data)
            archive.appendLittleEndian(UInt32(0x0403_4B50))
            archive.appendLittleEndian(UInt16(20))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(checksum)
            archive.appendLittleEndian(UInt32(file.data.count))
            archive.appendLittleEndian(UInt32(file.data.count))
            archive.appendLittleEndian(UInt16(name.count))
            archive.appendLittleEndian(UInt16(0))
            archive.append(name)
            archive.append(file.data)

            centralDirectory.appendLittleEndian(UInt32(0x0201_4B50))
            centralDirectory.appendLittleEndian(UInt16(20))
            centralDirectory.appendLittleEndian(UInt16(20))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(checksum)
            centralDirectory.appendLittleEndian(UInt32(file.data.count))
            centralDirectory.appendLittleEndian(UInt32(file.data.count))
            centralDirectory.appendLittleEndian(UInt16(name.count))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt32(0))
            centralDirectory.appendLittleEndian(localOffset)
            centralDirectory.append(name)
            localOffset = UInt32(archive.count)
        }

        let centralOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        archive.appendLittleEndian(UInt32(0x0605_4B50))
        archive.appendLittleEndian(UInt16(0))
        archive.appendLittleEndian(UInt16(0))
        archive.appendLittleEndian(UInt16(files.count))
        archive.appendLittleEndian(UInt16(files.count))
        archive.appendLittleEndian(UInt32(centralDirectory.count))
        archive.appendLittleEndian(centralOffset)
        archive.appendLittleEndian(UInt16(0))
        return archive
    }
}

private nonisolated enum CRC32 {
    static func checksum(_ data: Data) -> UInt32 {
        var value = UInt32.max
        for byte in data {
            var current = (value ^ UInt32(byte)) & 0xFF
            for _ in 0 ..< 8 {
                current = current & 1 == 1 ? (current >> 1) ^ 0xEDB8_8320 : current >> 1
            }
            value = (value >> 8) ^ current
        }
        return value ^ UInt32.max
    }
}

private nonisolated extension Data {
    mutating func appendLittleEndian(_ value: some FixedWidthInteger) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }
}
