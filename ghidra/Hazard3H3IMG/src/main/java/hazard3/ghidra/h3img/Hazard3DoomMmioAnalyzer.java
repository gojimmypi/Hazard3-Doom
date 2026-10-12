package hazard3.ghidra.h3img;

import ghidra.app.services.AbstractAnalyzer;
import ghidra.app.services.AnalyzerType;
import ghidra.app.util.importer.MessageLog;
import ghidra.framework.store.LockException;
import ghidra.program.model.address.Address;
import ghidra.program.model.address.AddressOverflowException;
import ghidra.program.model.address.AddressSetView;
import ghidra.program.model.address.AddressSpace;
import ghidra.program.model.data.DWordDataType;
import ghidra.program.model.listing.CommentType;
import ghidra.program.model.listing.Listing;
import ghidra.program.model.listing.Program;
import ghidra.program.model.mem.Memory;
import ghidra.program.model.mem.MemoryBlock;
import ghidra.program.model.mem.MemoryConflictException;
import ghidra.program.model.symbol.SourceType;
import ghidra.program.model.symbol.SymbolTable;
import ghidra.program.model.util.CodeUnitInsertionException;
import ghidra.util.exception.CancelledException;
import ghidra.util.exception.InvalidInputException;
import ghidra.util.task.TaskMonitor;

/**
 * Adds the current Hazard3-Doom APB/MMIO map to programs loaded from H3IMG.
 */
public class Hazard3DoomMmioAnalyzer extends AbstractAnalyzer {
    private static final String ANALYZER_NAME = "Hazard3-Doom MMIO Map";
    private static final String DESCRIPTION =
        "Creates volatile Hazard3-Doom APB blocks and names the current MMIO registers.";
    private static final String H3IMG_PAYLOAD_BLOCK = "h3img_payload";
    private static final String RISCV_LANGUAGE_ID = "RISCV:LE:32:default";

    @SuppressWarnings("this-escape")
    public Hazard3DoomMmioAnalyzer() {
        super(ANALYZER_NAME, DESCRIPTION, AnalyzerType.BYTE_ANALYZER);
        setDefaultEnablement(true);
        setSupportsOneTimeAnalysis();
    }

    @Override
    public boolean canAnalyze(Program program) {
        if (!RISCV_LANGUAGE_ID.equals(program.getLanguageID().getIdAsString())) {
            return false;
        }
        return program.getMemory().getBlock(H3IMG_PAYLOAD_BLOCK) != null;
    }

    @Override
    public boolean added(Program program, AddressSetView set, TaskMonitor monitor,
            MessageLog log) throws CancelledException {
        AddressSpace space = program.getAddressFactory().getDefaultAddressSpace();

        for (Hazard3DoomMmioMap.Peripheral peripheral : Hazard3DoomMmioMap.PERIPHERALS) {
            monitor.checkCancelled();
            ensurePeripheralBlock(program, space, peripheral, log);
            applyRegisters(program, space, peripheral, monitor, log);
        }

        log.appendMsg(ANALYZER_NAME,
            "Applied Hazard3-Doom timer/UART/GPIO/SAO/SD/video MMIO map");
        return true;
    }

    private void ensurePeripheralBlock(Program program, AddressSpace space,
            Hazard3DoomMmioMap.Peripheral peripheral, MessageLog log) {
        Memory memory = program.getMemory();
        Address start = space.getAddress(peripheral.base);
        Address end;
        try {
            end = start.addNoWrap(peripheral.size - 1);
        }
        catch (AddressOverflowException e) {
            log.appendMsg(ANALYZER_NAME,
                peripheral.blockName + ": range exceeds the address space");
            return;
        }

        MemoryBlock existingAtStart = memory.getBlock(start);
        if (existingAtStart != null && existingAtStart.contains(end)) {
            existingAtStart.setVolatile(true);
            return;
        }

        if (overlapsExistingBlock(memory, start, end)) {
            log.appendMsg(ANALYZER_NAME,
                peripheral.blockName + ": skipped block creation because the range overlaps " +
                "existing memory");
            return;
        }

        try {
            MemoryBlock block = memory.createUninitializedBlock(
                peripheral.blockName, start, peripheral.size, false);
            block.setPermissions(true, true, false);
            block.setVolatile(true);
            block.setComment(peripheral.comment);
            block.setSourceName(ANALYZER_NAME);
        }
        catch (LockException | MemoryConflictException | AddressOverflowException e) {
            log.appendMsg(ANALYZER_NAME, e.toString());
        }
    }

    private boolean overlapsExistingBlock(Memory memory, Address start, Address end) {
        for (MemoryBlock block : memory.getBlocks()) {
            if (start.compareTo(block.getEnd()) <= 0 && end.compareTo(block.getStart()) >= 0) {
                return true;
            }
        }
        return false;
    }

    private void applyRegisters(Program program, AddressSpace space,
            Hazard3DoomMmioMap.Peripheral peripheral, TaskMonitor monitor, MessageLog log)
            throws CancelledException {
        Memory memory = program.getMemory();
        Listing listing = program.getListing();
        SymbolTable symbols = program.getSymbolTable();

        for (Hazard3DoomMmioMap.Register register : peripheral.registers) {
            monitor.checkCancelled();
            Address address = space.getAddress(peripheral.base + register.offset);
            if (!memory.contains(address)) {
                log.appendMsg(ANALYZER_NAME,
                    register.name + ": skipped because the address is not mapped");
                continue;
            }

            try {
                symbols.createLabel(address, register.name, SourceType.IMPORTED);
            }
            catch (InvalidInputException | IllegalArgumentException e) {
                log.appendMsg(ANALYZER_NAME, e.toString());
            }

            if (listing.getDefinedDataAt(address) == null &&
                    listing.getInstructionAt(address) == null) {
                try {
                    listing.createData(address, DWordDataType.dataType);
                }
                catch (CodeUnitInsertionException e) {
                    log.appendMsg(ANALYZER_NAME,
                        register.name + ": could not create dword data: " + e.getMessage());
                }
            }

            String existingComment = listing.getComment(CommentType.EOL, address);
            if (existingComment == null || existingComment.isBlank()) {
                listing.setComment(address, CommentType.EOL, register.comment);
            }
        }
    }
}
