package hazard3.ghidra.h3img;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;

/**
 * Parser and validator for the fixed 64-byte Hazard3 H3IMG header.
 */
final class H3ImgHeader {
    static final long MAGIC = 0x31493348L; // "H3I1" as a little-endian uint32.
    static final int HEADER_BYTES = 64;
    static final long FORMAT_VERSION = 1;
    static final long FLAG_CRC32 = 1;
    static final int WORD_COUNT = 16;

    private static final long UINT32_SPACE_SIZE = 0x1_0000_0000L;

    private final long loadAddress;
    private final long imageBytes;
    private final long entryAddress;
    private final long bssAddress;
    private final long bssBytes;
    private final long payloadCrc32;

    private H3ImgHeader(long loadAddress, long imageBytes, long entryAddress,
            long bssAddress, long bssBytes, long payloadCrc32) {
        this.loadAddress = loadAddress;
        this.imageBytes = imageBytes;
        this.entryAddress = entryAddress;
        this.bssAddress = bssAddress;
        this.bssBytes = bssBytes;
        this.payloadCrc32 = payloadCrc32;
    }

    static H3ImgHeader parse(byte[] headerBytes, long fileLength) {
        if (headerBytes.length != HEADER_BYTES) {
            throw new IllegalArgumentException(
                "H3IMG header must be exactly " + HEADER_BYTES + " bytes");
        }

        ByteBuffer buffer = ByteBuffer.wrap(headerBytes).order(ByteOrder.LITTLE_ENDIAN);
        long[] words = new long[WORD_COUNT];
        for (int i = 0; i < WORD_COUNT; ++i) {
            words[i] = Integer.toUnsignedLong(buffer.getInt());
        }

        long magic = words[0];
        long encodedHeaderBytes = words[1];
        long formatVersion = words[2];
        long flags = words[3];
        long loadAddress = words[4];
        long imageBytes = words[5];
        long entryAddress = words[6];
        long bssAddress = words[7];
        long bssBytes = words[8];
        long payloadCrc32 = words[9];

        if (magic != MAGIC) {
            throw new IllegalArgumentException("invalid H3IMG magic; expected H3I1");
        }
        if (encodedHeaderBytes != HEADER_BYTES) {
            throw new IllegalArgumentException(
                "unsupported H3IMG header size " + encodedHeaderBytes);
        }
        if (formatVersion != FORMAT_VERSION) {
            throw new IllegalArgumentException(
                "unsupported H3IMG format version " + formatVersion);
        }
        if (flags != FLAG_CRC32) {
            throw new IllegalArgumentException(
                "unsupported H3IMG flags " + hex32(flags));
        }
        if (imageBytes == 0) {
            throw new IllegalArgumentException("H3IMG payload is empty");
        }
        if (fileLength != HEADER_BYTES + imageBytes) {
            throw new IllegalArgumentException(
                "H3IMG package length does not match its header");
        }
        for (int i = 10; i < WORD_COUNT; ++i) {
            if (words[i] != 0) {
                throw new IllegalArgumentException(
                    "H3IMG reserved header words must be zero");
            }
        }

        long imageEnd = checkedEnd(loadAddress, imageBytes, "payload");
        if (entryAddress < loadAddress || entryAddress >= imageEnd) {
            throw new IllegalArgumentException(
                "H3IMG entry address is outside the payload range");
        }

        if (bssBytes != 0) {
            long bssEnd = checkedEnd(bssAddress, bssBytes, "BSS");
            boolean overlaps = loadAddress < bssEnd && bssAddress < imageEnd;
            if (overlaps) {
                throw new IllegalArgumentException(
                    "H3IMG BSS overlaps the payload range");
            }
        }

        return new H3ImgHeader(loadAddress, imageBytes, entryAddress,
            bssAddress, bssBytes, payloadCrc32);
    }

    private static long checkedEnd(long start, long length, String rangeName) {
        long end = start + length;
        if (end < start || end > UINT32_SPACE_SIZE) {
            throw new IllegalArgumentException(
                "H3IMG " + rangeName + " range exceeds the 32-bit address space");
        }
        return end;
    }

    private static String hex32(long value) {
        return String.format("0x%08x", value & 0xffff_ffffL);
    }

    long loadAddress() {
        return loadAddress;
    }

    long imageBytes() {
        return imageBytes;
    }

    long entryAddress() {
        return entryAddress;
    }

    long bssAddress() {
        return bssAddress;
    }

    long bssBytes() {
        return bssBytes;
    }

    long payloadCrc32() {
        return payloadCrc32;
    }
}
