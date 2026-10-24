#!/usr/bin/env python3
"""Read-only GateMate conditional SPI jump feasibility check (v36).

Derives and validates the exact vendor-generated command suffix in memory.
No command suffix is saved as a bitstream or approved for CC_CFG_CTRL execution.
A passing host check does not establish device acceptance, SPI ownership,
or protected first-stage DFU installation at flash address zero.
"""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import subprocess
import tempfile

HERE = Path(__file__).resolve().parent


def load_dependency(filename, module_name):
    spec = importlib.util.spec_from_file_location(module_name, HERE / filename)
    if spec is None or spec.loader is None:
        raise ValueError("missing dependency: " + filename)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


V34 = load_dependency("audit-ulx5m-spi-multiboot-commands.py", "ulx5m_v36_base")
V35 = load_dependency("audit-ulx5m-spi-boot-layout.py", "ulx5m_v36_layout")
NATIVE_PACK_SHA = "35dcd1ccdcf3927e041918ffa8c7dd2c50467954b209d6f66ab6227a1b95b6eb"
TARGET = 0x201000


def digest(data):
    return hashlib.sha256(data).hexdigest()


def extract_command_pair(packed, target=TARGET):
    """Extract contiguous CRC-valid CFGRST/JUMP records, never a deployable image.

    This only proves that the commands exist in gmpack output. It does not
    prove that the configuration engine can accept them without framing,
    particularly from CC_CFG_CTRL in a running design.
    """
    commands = V34.find_commands(packed)
    resets = [c for c in commands if c["command"] == "CMD_CFGRST"]
    jumps = [c for c in commands if c["command"] == "CMD_JUMP"]
    if len(resets) != 1 or len(jumps) != 1:
        raise ValueError("expected exactly one verified reset and jump command")
    reset, jump = resets[0], jumps[0]
    start = int(reset["offset"], 16)
    second = int(jump["offset"], 16)
    if reset["bytes"] != 1 or reset["payload_hex"] != "00":
        raise ValueError("unexpected reset payload")
    if jump["bytes"] != 4 or jump.get("target_le") != "0x%08x" % target:
        raise ValueError("jump target/encoding is not the native entry point")
    if second != start + 7 or len(packed) < second + 10:
        raise ValueError("reset and jump must be adjacent, complete records")
    command_pair = packed[start:second + 10]
    if len(command_pair) != 17:
        raise ValueError("unexpected reset/jump command length")
    if V34.parse_command(command_pair, 0) is None or V34.parse_command(command_pair, 7) is None:
        raise ValueError("extracted command pair fails CRC verification")
    if packed[second + 10:] != b"\x00\x00":
        raise ValueError("unexpected bytes after jump; requalify trailer")
    return {
        "reset_offset": "0x%x" % start,
        "jump_offset": "0x%x" % second,
        "reset_bytes": 7,
        "jump_bytes": 10,
        "command_pair_bytes": 17,
        "command_pair_hex": command_pair.hex(),
        "command_pair_sha256": digest(command_pair),
        "jump_target": "0x%06x" % target,
        "acceptance_by_cc_cfg_ctrl": "UNPROVEN",
        "configuration_engine_spi_handoff": "UNPROVEN",
    }


def first_stage_policy(btn2_held, header_valid, payload_valid, *,
                       first_stage_dfu_installed=False,
                       first_stage_protected=False,
                       allow_experimental_handoff=False):
    """Abstract policy only. Returns a *desired decision*, not FPGA behavior.

    The shipped board's address-zero factory image has NOT been established as
    our persistent DFU first stage. Consequently, live decisions are BLOCKED.
    """
    if not first_stage_dfu_installed or not first_stage_protected:
        return "BLOCKED_NO_PROTECTED_DFU_STAGE0"
    if btn2_held:
        return "STAY_DFU_BTN2"
    if not header_valid or not payload_valid:
        return "STAY_DFU_INVALID_APP"
    if not allow_experimental_handoff:
        return "STAY_DFU_HANDOFF_NOT_AUTHORIZED"
    return "CANDIDATE_JUMP_ONLY_NOT_HARDWARE_PROVEN"


def replay_recovery_model():
    # Synthetic model: stage0 installed/protected is an assumption, NOT a fact.
    stage = {"first_stage_dfu_installed": True,
             "first_stage_protected": True,
             "allow_experimental_handoff": True}
    cases = {
        "power_on_btn2_held": first_stage_policy(True, False, False, **stage),
        "power_on_corrupt_header": first_stage_policy(False, False, True, **stage),
        "power_on_corrupt_payload": first_stage_policy(False, True, False, **stage),
        "power_on_valid_candidate": first_stage_policy(False, True, True, **stage),
        "power_cycle_btn2_after_failed_candidate": first_stage_policy(True, False, False, **stage),
        "current_factory_configuration": first_stage_policy(False, True, True),
    }
    required = {
        "power_on_btn2_held": "STAY_DFU_BTN2",
        "power_on_corrupt_header": "STAY_DFU_INVALID_APP",
        "power_on_corrupt_payload": "STAY_DFU_INVALID_APP",
        "power_on_valid_candidate": "CANDIDATE_JUMP_ONLY_NOT_HARDWARE_PROVEN",
        "power_cycle_btn2_after_failed_candidate": "STAY_DFU_BTN2",
        "current_factory_configuration": "BLOCKED_NO_PROTECTED_DFU_STAGE0",
    }
    if cases != required:
        raise AssertionError("abstract boot-selection safety model changed")
    return cases


def run_packer_native(implementation, packer="gmpack", runner=None):
    if runner is None:
        runner = subprocess.run
    with tempfile.TemporaryDirectory(prefix="ulx5m-v36-offline-only-") as tmp:
        out = Path(tmp) / "candidate.bit"
        args = [packer, "--bootaddr", str(TARGET), str(implementation), str(out)]
        result = runner(args, capture_output=True, text=True, check=False)
        if result.returncode or not out.is_file():
            raise RuntimeError("gmpack native command generation failed: " + result.stderr)
        payload = out.read_bytes()
        if digest(payload) != NATIVE_PACK_SHA or len(payload) != 3045:
            raise ValueError("pinned v35 native stream mismatch")
        pair = extract_command_pair(payload)
    return pair


def perform(bit_path, implementation, root, packer="gmpack", runner=None, verify_c=True):
    bit = V34.verify_inputs(bit_path, implementation)
    firmware = V35.check_firmware_policy(root)
    V35.check_flash_regions(V35.HEADER_ADDRESS, TARGET, len(bit))
    if verify_c:
        V35.run_c_probe(root, bit)
    pair = run_packer_native(implementation, packer, runner)
    model = replay_recovery_model()
    return {
        "result": "BLOCKED - host command syntax and conditional policy only",
        "evidence": "v35 validated flash layout and C parser, v36 validates reset/jump suffix",
        "command_pair": pair,
        "abstract_recovery_model": model,
        "first_stage_dfu_at_flash_zero_verified": False,
        "first_stage_flash_write_protection_verified": False,
        "on_device_cc_cfg_ctrl_jump_accepted": False,
        "independent_btn2_recovery_verified": False,
        "firmware_legacy_offset_incompatible": firmware["existing_normal_boot"],
        "flash_write_authorized": False,
        "hardware_attempt_authorized": False,
        "persistent_boot_authorized": False,
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bit", required=True, type=Path)
    parser.add_argument("--implementation", required=True, type=Path)
    parser.add_argument("--repo-root", type=Path, default=HERE.parent)
    parser.add_argument("--packer", default="gmpack")
    args = parser.parse_args(argv)
    try:
        report = perform(args.bit, args.implementation, args.repo_root, args.packer)
    except (ValueError, OSError, RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(1, "[FAIL] %s\n" % error)
    print("[PASS] Pinned app input, C parser, flash layout and firmware policy verified")
    print("[PASS] Exact v35 0x201000 vendor-generated native image reproduced")
    print("[PASS] CRC-verified 17-byte adjacent CFGRST/JUMP pair extracted in memory")
    print("[PASS] Abstract conditional BTN2 and corrupt-image policy cases")
    print("[UNKNOWN] No evidence command pair alone is a valid CC_CFG_CTRL stream")
    print("[BLOCK] Persistent DFU stage0, flash protection, SPI handoff and fallback unproven")
    print("[BLOCK] No flash output, programming, USB, JTAG or FPGA operations")
    print(json.dumps(report, sort_keys=True, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
