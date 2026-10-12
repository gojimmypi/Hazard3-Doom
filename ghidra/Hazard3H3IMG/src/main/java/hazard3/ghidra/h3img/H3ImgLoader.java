package hazard3.ghidra.h3img;

import java.io.IOException;
import java.io.InputStream;
import java.util.Collection;
import java.util.List;
import java.util.zip.CRC32;

import ghidra.app.util.MemoryBlockUtils;
import ghidra.app.util.bin.ByteProvider;
import ghidra.app.util.opinion.AbstractProgramLoader;
import ghidra.app.util.opinion.LoadException;
import ghidra.app.util.opinion.LoadSpec;
import ghidra.app.util.opinion.Loaded;
import ghidra.app.util.opinion.Loader.ImporterSettings;
import ghidra.app.util.opinion.LoaderTier;
import ghidra.program.database.mem.FileBytes;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressOverflowException;
import ghidra.program.model.address.AddressSpace;
import ghidra.program.model.lang.CompilerSpecID;
import ghidra.program.model.lang.Language;
import ghidra.program.model.lang.LanguageCompilerSpecPair;
import ghidra.program.model.lang.LanguageID;
import ghidra.program.model.listing.Program;
import ghidra.program.model.mem.MemoryBlock;
import ghidra.program.model.symbol.SourceType;
import ghidra.program.model.symbol.SymbolTable;
import ghidra.util.exception.CancelledException;
import ghidra.util.exception.InvalidInputException;

/**
 * Ghidra loader for Hazard3-Doom H3IMG application images.
 */
public class H3ImgLoader extends AbstractProgramLoader {
    private static final String LOADER_NAME = "Hazard3 H3IMG";
    private static final String LANGUAGE_ID = "RISCV:LE:32:default";
    private static final String COMPILER_SPEC_ID = "gcc";
    private static final String BLOCK_SOURCE = "Hazard3 H3IMG Loader";
    private static final int CRC_BUFFER_BYTES = 64 * 1024;

    @Override
    public String getName() {
        return LOADER_NAME;
    }

    @Override
    public LoaderTier getTier() {
        return LoaderTier.SPECIALIZED_TARGET_LOADER;
    }

    @Override
    public int getTierPriority() {
        return 50;
    }

    @Override
    public boolean supportsLoadIntoProgram(Program program) {
        return false;
    }

    @Override
    public Collection<LoadSpec> findSupportedLoadSpecs(ByteProvider provider) throws IOException {
        if (provider.length() < H3ImgHeader.HEADER_BYTES) {
            return List.of();
        }

        H3ImgHeader header;
        try {
            header = parseHeader(provider);
        }
        catch (IllegalArgumentException e) {
            return List.of();
        }

        LanguageCompilerSpecPair pair = new LanguageCompilerSpecPair(
            new LanguageID(LANGUAGE_ID), new CompilerSpecID(COMPILER_SPEC_ID));
        return List.of(new LoadSpec(this, header.loadAddress(), pair, true));
    }

    @Override
    protected List<Loaded<Program>> loadProgram(ImporterSettings settings)
            throws IOException, LoadException, CancelledException {
        H3ImgHeader header = parseHeaderForLoad(settings.provider());
        LanguageCompilerSpecPair pair = settings.loadSpec().getLanguageCompilerSpec();
        Language language = getLanguageService().getLanguage(pair.languageID);
        AddressSpace space = language.getAddressFactory().getDefaultAddressSpace();
        Address imageBase = space.getAddress(header.loadAddress());

        Program program = createProgram(imageBase, settings);
        Loaded<Program> loaded = new Loaded<>(program, settings);
        boolean success = false;
        try {
            loadInto(program, settings);
            createDefaultMemoryBlocks(program, settings);
            success = true;
            return List.of(loaded);
        }
        finally {
            if (!success) {
                loaded.close();
            }
        }
    }

    @Override
    protected void loadProgramInto(Program program, ImporterSettings settings)
            throws IOException, LoadException, CancelledException {
        ByteProvider provider = settings.provider();
        H3ImgHeader header = parseHeaderForLoad(provider);
        verifyPayloadCrc32(provider, header, settings);

        AddressSpace space = program.getAddressFactory().getDefaultAddressSpace();
        Address loadAddress = space.getAddress(header.loadAddress());
        Address entryAddress = space.getAddress(header.entryAddress());
        Address bssAddress = space.getAddress(header.bssAddress());

        FileBytes fileBytes = MemoryBlockUtils.createFileBytes(program, provider,
            H3ImgHeader.HEADER_BYTES, header.imageBytes(), settings.monitor());

        MemoryBlock payloadBlock;
        try {
            payloadBlock = MemoryBlockUtils.createInitializedBlock(program, false,
                "h3img_payload", loadAddress, fileBytes, 0, header.imageBytes(),
                "H3IMG executable payload", BLOCK_SOURCE, true, true, true, settings.log());
        }
        catch (AddressOverflowException e) {
            throw new LoadException("H3IMG payload exceeds the address space", e);
        }
        if (payloadBlock == null) {
            throw new LoadException("failed to create the H3IMG payload memory block");
        }

        if (header.bssBytes() != 0) {
            MemoryBlock bssBlock = MemoryBlockUtils.createUninitializedBlock(program, false,
                "h3img_bss", bssAddress, header.bssBytes(), "H3IMG BSS", BLOCK_SOURCE,
                true, true, false, settings.log());
            if (bssBlock == null) {
                throw new LoadException("failed to create the H3IMG BSS memory block");
            }
        }

        createLabels(program, loadAddress, entryAddress, bssAddress, header, settings);
        settings.log().appendMsg(String.format(
            "H3IMG: load=0x%08x bytes=0x%08x entry=0x%08x bss=0x%08x " +
            "bss_bytes=0x%08x crc32=0x%08x",
            header.loadAddress(), header.imageBytes(), header.entryAddress(),
            header.bssAddress(), header.bssBytes(), header.payloadCrc32()));
    }

    private H3ImgHeader parseHeader(ByteProvider provider) throws IOException {
        byte[] bytes = provider.readBytes(0, H3ImgHeader.HEADER_BYTES);
        return H3ImgHeader.parse(bytes, provider.length());
    }

    private H3ImgHeader parseHeaderForLoad(ByteProvider provider) throws IOException, LoadException {
        try {
            return parseHeader(provider);
        }
        catch (IllegalArgumentException e) {
            throw new LoadException(e.getMessage(), e);
        }
    }

    private void verifyPayloadCrc32(ByteProvider provider, H3ImgHeader header,
            ImporterSettings settings) throws IOException, LoadException, CancelledException {
        CRC32 crc32 = new CRC32();
        byte[] buffer = new byte[CRC_BUFFER_BYTES];
        long remaining = header.imageBytes();

        try (InputStream input = provider.getInputStream(H3ImgHeader.HEADER_BYTES)) {
            while (remaining != 0) {
                settings.monitor().checkCancelled();
                int requested = (int) Math.min(buffer.length, remaining);
                int count = input.read(buffer, 0, requested);
                if (count < 0) {
                    throw new LoadException("unexpected end of H3IMG payload while checking CRC32");
                }
                crc32.update(buffer, 0, count);
                remaining -= count;
            }
        }

        long actual = crc32.getValue() & 0xffff_ffffL;
        if (actual != header.payloadCrc32()) {
            throw new LoadException(String.format(
                "H3IMG payload CRC32 mismatch: expected 0x%08x, calculated 0x%08x",
                header.payloadCrc32(), actual));
        }
        settings.log().appendMsg(String.format(
            "H3IMG payload CRC32 verified: 0x%08x", actual));
    }

    private void createLabels(Program program, Address loadAddress, Address entryAddress,
            Address bssAddress, H3ImgHeader header, ImporterSettings settings)
            throws LoadException {
        SymbolTable symbols = program.getSymbolTable();
        try {
            symbols.createLabel(loadAddress, "h3img_image_start", SourceType.IMPORTED);
            symbols.createLabel(entryAddress, "h3img_entry", SourceType.IMPORTED);
            symbols.addExternalEntryPoint(entryAddress);
            if (header.bssBytes() != 0) {
                symbols.createLabel(bssAddress, "h3img_bss", SourceType.IMPORTED);
            }
        }
        catch (InvalidInputException | IllegalArgumentException e) {
            throw new LoadException("failed to create H3IMG symbols", e);
        }
    }
}
